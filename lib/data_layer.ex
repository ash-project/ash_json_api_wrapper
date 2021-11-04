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
      fields: [@field]
    ],
    args: [:action]
  }

  @get_endpoint %Ash.Dsl.Entity{
    name: :get_endpoint,
    target: AshJsonApiWrapper.Endpoint,
    schema: AshJsonApiWrapper.Endpoint.get_schema(),
    docs: """
    Configure the endpoint that a given action will use.

    Accepts overrides for fields as well.

    Expresses that this endpoint is used to fetch a single item.
    Doing this will make the data layer support equality filters over that field when using that action.
    If "in" or "or equals" is used, then multiple requests will be made in parallel to fetch
    all of those records. However, keep in mind you can't combine a filter over one of these
    fields with an `or` with anything other than *more* filters on this field. For example        Doing this will make the data layer support equality filters over that field.
    If "in" or "or equals" is used, then multiple requests will be made in parallel to fetch
    all of those records. However, keep in mind you can't combine a filter over one of these
    fields with an `or` with anything other than *more* filters on this field. For example,
    `filter(resource, id == 1 or foo == true)`, since we wouldn't be able to turn this into
    multiple requests to the get endpoint for `id`. If other filters are supported, they can be used
    with `and`, e.g `filter(resource, id == 1 or id == 2 and other_supported_filter == true)`, since those
    filters will be applied to each request.

    Expects the field to be available in the path template, e.g with `get_for :id`, path should contain `:id`, e.g
    `/get/:id` or `/:id`,
    `filter(resource, id == 1 or foo == true)`, since we wouldn't be able to turn this into
    multiple requests to the get endpoint for `id`. If other filters are supported, they can be used
    with `and`, e.g `filter(resource, id == 1 or id == 2 and other_supported_filter == true)`, since those
    filters will be applied to each request.

    Expects the field to be available in the path template, e.g with `get_for :id`, path should contain `:id`, e.g
    `/get/:id` or `/:id`
    """,
    entities: [
      fields: [@field]
    ],
    args: [:action, :get_for]
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
      @endpoint,
      @get_endpoint
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

  require Logger
  use Ash.Dsl.Extension, sections: [@json_api_wrapper]

  defmodule Query do
    defstruct [
      :request,
      :action,
      :limit,
      :offset,
      :filter,
      :endpoint,
      :templates,
      :override_results
    ]
  end

  @behaviour Ash.DataLayer

  @impl true
  def can?(_, :create), do: true
  def can?(_, :boolean_filter), do: true
  def can?(_, :filter), do: true
  def can?(_, :limit), do: true
  def can?(_, :offset), do: true

  def can?(
        _,
        {:filter_expr,
         %Ash.Query.Operator.Eq{
           left: %Ash.Query.Operator.Eq{left: %Ash.Query.Ref{}, right: %Ash.Query.Ref{}}
         }}
      ),
      do: false

  def can?(
        _,
        {:filter_expr, %Ash.Query.Operator.Eq{right: %Ash.Query.Ref{}}}
      ),
      do: true

  def can?(
        _,
        {:filter_expr, %Ash.Query.Operator.Eq{left: %Ash.Query.Ref{}}}
      ),
      do: true

  def can?(_, _), do: false

  @impl true
  def resource_to_query(resource) do
    %Query{request: Finch.build(:get, AshJsonApiWrapper.endpoint_base(resource))}
  end

  @impl true
  def filter(query, filter, resource) do
    if query.action do
      case validate_filter(filter, resource, query.action) do
        {:ok, {filter, endpoint, templates}} ->
          {:ok, %{query | filter: filter, endpoint: endpoint, templates: templates}}

        {:error, error} ->
          {:error, error}
      end
    else
      {:ok, %{query | filter: filter}}
    end
  end

  @impl true
  def set_context(_resource, query, context) do
    params = context[:data_layer][:query_params]

    action = context[:action]

    if params do
      {:ok,
       %{
         query
         | request: %{query.request | query: params},
           action: action
       }}
    else
      {:ok, %{query | action: action}}
    end
  end

  defp validate_filter(filter, resource, action) when filter in [nil, true] do
    {:ok, {nil, AshJsonApiWrapper.endpoint(resource, action.name), []}}
  end

  defp validate_filter(filter, resource, action) do
    case find_filter_that_uses_get_endpoint(filter, resource, action) do
      {:ok, {remaining_filter, get_endpoint, templates}} ->
        {:ok, {remaining_filter, get_endpoint, templates}}

      {:ok, nil} ->
        {:ok, {nil, AshJsonApiWrapper.endpoint(resource, action.name), []}}

      {:error, error} ->
        {:error, error}
    end
  end

  defp find_filter_that_uses_get_endpoint(
         expr,
         resource,
         action,
         templates \\ [],
         in_an_or? \\ false,
         uses_endpoint \\ nil
       )

  defp find_filter_that_uses_get_endpoint(
         %Ash.Filter{expression: expression},
         resource,
         action,
         templates,
         in_an_or?,
         uses_endpoint
       ) do
    find_filter_that_uses_get_endpoint(
      expression,
      resource,
      action,
      templates,
      in_an_or?,
      uses_endpoint
    )
  end

  defp find_filter_that_uses_get_endpoint(
         %Ash.Query.BooleanExpression{op: :and, left: left, right: right},
         resource,
         action,
         templates,
         in_an_or?,
         uses_endpoint
       ) do
    case find_filter_that_uses_get_endpoint(left, resource, action, templates, in_an_or?) do
      {:ok, {left_remaining, get_endpoint, left_templates}} ->
        if uses_endpoint && get_endpoint != uses_endpoint do
          {:error,
           "Filter would cause the usage of different endpoints: #{inspect(uses_endpoint)} and #{inspect(get_endpoint)}"}
        else
          case find_filter_that_uses_get_endpoint(right, resource, action, templates, in_an_or?) do
            {:ok, {right_remaining, get_endpoint, right_templates}} ->
              if uses_endpoint && get_endpoint != uses_endpoint do
                {:error,
                 "Filter would cause the usage of different endpoints: #{inspect(uses_endpoint)} and #{inspect(get_endpoint)}"}
              else
                {:ok,
                 {Ash.Query.BooleanExpression.new(:and, left_remaining, right_remaining),
                  uses_endpoint, left_templates ++ right_templates ++ templates}}
              end
          end
        end

      {:ok, nil} ->
        case find_filter_that_uses_get_endpoint(right, resource, action, templates, in_an_or?) do
          {:ok, {right_remaining, get_endpoint, right_templates}} ->
            if uses_endpoint && get_endpoint != uses_endpoint do
              {:error,
               "Filter would cause the usage of different endpoints: #{inspect(uses_endpoint)} and #{inspect(get_endpoint)}"}
            else
              {:ok, {right_remaining, uses_endpoint, right_templates ++ templates}}
            end
        end

      {:error, error} ->
        {:error, error}
    end
  end

  defp find_filter_that_uses_get_endpoint(
         %Ash.Query.BooleanExpression{op: :or, left: left, right: right} = expr,
         resource,
         action,
         templates,
         _in_an_or?,
         uses_endpoint
       ) do
    case find_filter_that_uses_get_endpoint(left, resource, action, templates, true) do
      {:ok, nil} ->
        case find_filter_that_uses_get_endpoint(right, resource, action, templates, true) do
          {:ok, nil} ->
            {:ok, {expr, uses_endpoint, []}}

          {:error, error} ->
            {:error, error}
        end

      {:error, error} ->
        {:error, error}

      _ ->
        raise "Unreachable!"
    end
  end

  defp find_filter_that_uses_get_endpoint(
         %Ash.Query.Operator.Eq{left: %Ash.Query.Ref{}, right: %Ash.Query.Ref{}},
         _,
         _,
         _,
         _,
         _
       ) do
    {:error,
     "References on both sides of operators not supported in ash_json_api_wrapper currently"}
  end

  defp find_filter_that_uses_get_endpoint(
         %Ash.Query.Operator.Eq{
           left: left,
           right: %Ash.Query.Ref{} = right
         } = op,
         resource,
         action,
         templates,
         in_an_or?,
         uses_endpoint
       ) do
    find_filter_that_uses_get_endpoint(
      %{op | right: left, left: right},
      resource,
      action,
      templates,
      in_an_or?,
      uses_endpoint
    )
  end

  defp find_filter_that_uses_get_endpoint(
         %Ash.Query.Operator.Eq{
           left: %Ash.Query.Ref{relationship_path: [], attribute: attribute},
           right: value
         },
         resource,
         action,
         templates,
         in_an_or?,
         uses_endpoint
       ) do
    case AshJsonApiWrapper.get_endpoint(resource, action.name, attribute.name) do
      nil ->
        {:ok, nil}

      get_endpoint ->
        if in_an_or? do
          {:error, "Cannot use get_endpoint attributes in an `or` clause of a filter."}
        else
          if uses_endpoint && get_endpoint != uses_endpoint do
            {:error,
             "Filter would cause the usage of different endpoints: #{inspect(uses_endpoint)} and #{inspect(get_endpoint)}"}
          else
            {:ok, {nil, get_endpoint, [{attribute.name, value} | templates]}}
          end
        end
    end
  end

  @impl true
  def limit(query, limit, _resource) do
    {:ok, %{query | limit: limit}}
  end

  @impl true
  def offset(query, offset, _resource) do
    {:ok, %{query | offset: offset}}
  end

  @impl true
  def create(resource, changeset) do
    endpoint = AshJsonApiWrapper.endpoint(resource, changeset.action.name)

    base =
      case endpoint.fields_in || :body do
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

    request =
      :post
      |> Finch.build(
        endpoint.path || AshJsonApiWrapper.endpoint_base(resource),
        [{"Content-Type", "application/json"}, {"Accept", "application/json"}],
        body
      )
      |> Map.put(:query, params)

    with {:ok, %{status: status} = response} when status >= 200 and status < 300 <-
           request(request, resource),
         {:ok, body} <- Jason.decode(response.body),
         {:ok, entities} <- get_entities(body, endpoint),
         {:ok, processed} <- process_entities(entities, resource) do
      {:ok, Enum.at(processed, 0)}
    else
      {:ok, %{status: status} = response} ->
        {:error,
         "Received status code #{status} in request #{inspect(request)}. Response: #{inspect(response)}"}

      other ->
        other
    end
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
  def run_query(%{override_results: results}, _resource) when not is_nil(results) do
    {:ok, results}
  end

  def run_query(query, resource) do
    if query.templates do
      query.templates
      |> Task.async_stream(
        fn template ->
          query = %{
            query
            | request: Finch.build(:get, fill_template(query.endpoint.path, template)),
              templates: nil
          }

          run_query(query, resource)
        end,
        timeout: :infinity
      )
      |> Enum.reduce_while(
        {:ok, []},
        fn
          {:ok, {:ok, results}}, {:ok, all_results} ->
            {:cont, {:ok, results ++ all_results}}

          {:ok, {:error, error}}, _ ->
            {:halt, {:error, error}}

          {:exit, reason}, _ ->
            {:error, "Request process exited with #{inspect(reason)}"}
        end
      )
    else
      endpoint = query.endpoint || AshJsonApiWrapper.endpoint(resource, query.action.name)

      with {:ok, %{status: status} = response} when status >= 200 and status < 300 <-
             request(query.request, resource),
           {:ok, body} <- Jason.decode(response.body),
           {:ok, entities} <- get_entities(body, endpoint) do
        entities
        |> limit_offset(query)
        |> process_entities(resource)
      else
        {:ok, %{status: status} = response} ->
          {:error,
           "Received status code #{status} in request #{inspect(query.request)}. Response: #{inspect(response)}"}

        other ->
          other
      end
    end
  end

  defp fill_template(string, template) do
    template
    |> List.wrap()
    |> Enum.reduce(string, fn {key, replacement}, acc ->
      String.replace(acc, ":#{key}", replacement)
    end)
  end

  defp limit_offset(results, %Query{limit: limit, offset: offset}) do
    results =
      if offset do
        Enum.drop(results, offset)
      else
        results
      end

    if limit do
      Enum.take(results, limit)
    else
      results
    end
  end

  defp request(request, resource) do
    case AshJsonApiWrapper.before_request(resource) do
      nil ->
        request
        |> encode_query()
        |> encode_body()
        |> log_send()
        |> Finch.request(AshJsonApiWrapper.finch(resource))
        |> log_resp()

      hook ->
        request
        |> hook.()
        |> encode_query()
        |> encode_body()
        |> log_send()
        |> Finch.request(AshJsonApiWrapper.finch(resource))
        |> log_resp()
    end
  end

  defp log_send(request) do
    Logger.debug("Sending request: #{inspect(request)}")
    request
  end

  defp log_resp(response) do
    Logger.debug("Received response: #{inspect(response)}")
    response
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
