defmodule AshJsonApiWrapper.DataLayer do
  @field %Ash.Dsl.Entity{
    name: :field,
    target: AshJsonApiWrapper.Field,
    schema: AshJsonApiWrapper.Field.schema(),
    docs: """
    Configure an individual field's behavior, for example its path in the response.
    """,
    args: [:name]
  }

  @fields %Ash.Dsl.Section{
    name: :fields,
    describe: "Contains configuration for individual fields in the response",
    entities: [
      @field
    ]
  }

  @endpoint %Ash.Dsl.Entity{
    name: :endpoint,
    target: AshJsonApiWrapper.Endpoint,
    schema: AshJsonApiWrapper.Endpoint.schema(),
    docs: """
    Configure the endpoint that a given action will use.

    Accepts overrides for fields as well.
    """,
    entities: [
      fields: @field
    ],
    args: [:action]
  }

  @endpoints %Ash.Dsl.Section{
    name: :endpoints,
    describe: "Contains the configuration for the endpoints used in each action",
    schema: [
      base: [
        type: :string,
        doc: "The base endpoint to which all relative urls provided will be appended."
      ]
    ],
    entities: [
      @endpoint
    ]
  }

  @json_api_wrapper %Ash.Dsl.Section{
    name: :json_api_wrapper,
    describe: "Contains the configuration for the json_api_wrapper data layer",
    sections: [
      @fields,
      @endpoints
    ],
    schema: [
      before_request: [
        type: :any,
        doc: """
        A function that takes the finch request and returns the finch request.
        Will be called just before the request is made for all requests, but before JSON encoding the body and query encoding the query parameters.
        """
      ],
      finch: [
        type: :atom,
        required: true,
        doc: """
        The name used when setting up your finch supervisor in your Application.

        e.g in this example from finch's readme:

        ```elixir
        {Finch, name: MyConfiguredFinch <- this value}
        ```
        """
      ]
    ]
  }

  use Ash.Dsl.Extension, sections: [@json_api_wrapper]

  defmodule Query do
    defstruct [:request, :action]
  end

  @behaviour Ash.DataLayer

  @impl true
  def can?(_, :create), do: true
  def can?(_, _), do: false

  @impl true
  def resource_to_query(resource) do
    %Query{request: Finch.build(:get, AshJsonApiWrapper.endpoint_base(resource))}
  end

  @impl true
  def set_context(_resource, query, context) do
    params = context[:data_layer][:query_params]

    if params do
      {:ok, %{query | request: %{query.request | query: params}, action: context[:action]}}
    else
      {:ok, %{query | action: context[:action]}}
    end
  end

  @impl true
  def create(resource, changeset) do
    endpoint = AshJsonApiWrapper.endpoint(resource, changeset.action.name)

    base =
      case endpoint && endpoint.fields_in do
        :body ->
          changeset.context[:data_layer][:body] || %{}

        :params ->
          changeset.context[:data_layer][:query_params] || %{}
      end

    {:ok, with_attrs} =
      changeset.attributes
      |> Kernel.||(%{})
      |> Enum.reduce_while({:ok, base}, fn {key, value}, {:ok, acc} ->
        attribute = Ash.Resource.Info.attribute(resource, key)
        field = AshJsonApiWrapper.field(resource, attribute.name)

        case Ash.Type.dump_to_embedded(
               attribute.type,
               value,
               attribute.constraints
             ) do
          {:ok, dumped} ->
            path =
              if field && field.write_path do
                field.write_path
              else
                [to_string(attribute.name)]
              end

            path =
              if endpoint.write_entity_path do
                endpoint.write_entity_path ++ path
              else
                path
              end

            {:cont, {:ok, put_in!(acc, path, dumped)}}

          :error ->
            {:halt,
             {:error,
              Ash.Error.Changes.InvalidAttribute.exception(
                field: attribute.name,
                message: "Could not be dumped to embedded"
              )}}
        end
      end)

    {body, params} =
      case endpoint.fields_in do
        :params ->
          {changeset.context[:data_layer][:body] || %{}, with_attrs}

        :body ->
          {with_attrs, changeset.context[:data_layer][:query_params] || %{}}
      end

    :post
    |> Finch.build(
      endpoint.path || AshJsonApiWrapper.endpoint_base(resource),
      [{"Content-Type", "application/json"}, {"Accept", "application/json"}],
      body
    )
    |> Map.put(:query, params)
    |> request(resource)

    {:ok, struct(resource, [])}
  end

  defp put_in!(body, [key], value) do
    Map.put(body, key, value)
  end

  defp put_in!(body, [first | rest], value) do
    body
    |> Map.put_new(first, %{})
    |> Map.update!(first, &put_in!(&1, rest, value))
  end

  @impl true
  def run_query(query, resource) do
    endpoint = AshJsonApiWrapper.endpoint(resource, query.action.name)

    with {:ok, %{status: status} = response} when status >= 200 and status < 300 <-
           request(query.request, resource),
         {:ok, body} <- Jason.decode(response.body),
         {:ok, entities} <- get_entities(body, endpoint) do
      process_entities(entities, resource)
    else
      {:ok, %{status: status} = response} ->
        {:error,
         "Received status code #{status} in request #{inspect(query.request)}. Response: #{inspect(response)}"}

      other ->
        other
    end
  end

  defp request(request, resource) do
    case AshJsonApiWrapper.before_request(resource) do
      nil ->
        request
        |> encode_query()
        |> encode_body()
        |> IO.inspect()
        |> Finch.request(AshJsonApiWrapper.finch(resource))

      hook ->
        request
        |> hook.()
        |> encode_query()
        |> encode_body()
        |> IO.inspect()
        |> Finch.request(AshJsonApiWrapper.finch(resource))
    end
    |> IO.inspect()
  end

  defp encode_query(%{query: query} = request) when is_map(query) do
    %{request | query: URI.encode_query(query)}
  end

  defp encode_query(request), do: request

  defp encode_body(%{body: body} = request) when is_map(body) do
    %{request | body: Jason.encode!(body)}
  end

  defp encode_body(request), do: request

  defp process_entities(entities, resource) do
    Enum.reduce_while(entities, {:ok, []}, fn entity, {:ok, entities} ->
      case process_entity(entity, resource) do
        {:ok, entity} -> {:cont, {:ok, [entity | entities]}}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, entities} -> {:ok, Enum.reverse(entities)}
      {:error, error} -> {:error, error}
    end
  end

  defp process_entity(entity, resource) do
    resource
    |> Ash.Resource.Info.attributes()
    |> Enum.reduce_while(
      {:ok,
       struct(resource,
         __meta__: %Ecto.Schema.Metadata{
           state: :loaded
         }
       )},
      fn attr, {:ok, record} ->
        case get_field(entity, attr, resource) do
          {:ok, value} ->
            {:cont, {:ok, Map.put(record, attr.name, value)}}

          {:error, error} ->
            {:halt, {:error, error}}
        end
      end
    )
  end

  defp get_field(entity, attr, resource) do
    raw_value = get_raw_value(entity, attr, resource)

    case Ash.Type.cast_stored(attr.type, raw_value, attr.constraints) do
      {:ok, value} ->
        {:ok, value}

      _ ->
        {:error,
         AshJsonApiWrapper.Errors.InvalidData.exception(field: attr.name, value: raw_value)}
    end
  end

  defp get_raw_value(entity, attr, resource) do
    case Enum.find(AshJsonApiWrapper.fields(resource), &(&1.name == attr.name)) do
      %{path: path} when not is_nil(path) ->
        case ExJSONPath.eval(entity, path) do
          {:ok, [value | _]} ->
            value

          _ ->
            nil
        end

      _ ->
        Map.get(entity, to_string(attr.name))
    end
  end

  defp get_entities(body, endpoint) do
    case endpoint.entity_path do
      nil ->
        {:ok, List.wrap(body)}

      path ->
        case ExJSONPath.eval(body, path) do
          {:ok, [entities | _]} ->
            {:ok, List.wrap(entities)}

          {:ok, _} ->
            {:ok, []}

          {:error, error} ->
            {:error, error}
        end
    end
  end
end
