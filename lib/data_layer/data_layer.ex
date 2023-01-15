defmodule AshJsonApiWrapper.DataLayer do
  @field %Spark.Dsl.Entity{
    name: :field,
    target: AshJsonApiWrapper.Field,
    schema: AshJsonApiWrapper.Field.schema(),
    docs: """
    Configure an individual field's behavior, for example its path in the response.
    """,
    args: [:name]
  }

  @fields %Spark.Dsl.Section{
    name: :fields,
    describe: "Contains configuration for individual fields in the response",
    entities: [
      @field
    ]
  }

  @endpoint %Spark.Dsl.Entity{
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

  @get_endpoint %Spark.Dsl.Entity{
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

    Expects the field to be available in the path template, e.g with `get_for` of `:id`, path should contain `:id`, e.g
    `/get/:id` or `/:id`,
    `filter(resource, id == 1 or foo == true)`, since we wouldn't be able to turn this into
    multiple requests to the get endpoint for `id`. If other filters are supported, they can be used
    with `and`, e.g `filter(resource, id == 1 or id == 2 and other_supported_filter == true)`, since those
    filters will be applied to each request.

    Expects the field to be available in the path template, e.g with `get_for` of `:id`, path should contain `:id`, e.g
    `/get/:id` or `/:id`
    """,
    entities: [
      fields: [@field]
    ],
    args: [:action, :get_for]
  }

  @endpoints %Spark.Dsl.Section{
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

  @json_api_wrapper %Spark.Dsl.Section{
    name: :json_api_wrapper,
    describe: "Contains the configuration for the json_api_wrapper data layer",
    sections: [
      @fields,
      @endpoints
    ],
    imports: [
      AshJsonApiWrapper.Paginator.Builtins
    ],
    schema: [
      before_request: [
        type:
          {:spark_function_behaviour, AshJsonApiWrapper.Finch.Plug,
           {AshJsonApiWrapper.Finch.Plug.Function, 2}},
        doc: """
        A function that takes the finch request and returns the finch request.
        Will be called just before the request is made for all requests, but before JSON encoding the body and query encoding the query parameters.
        """
      ],
      base_entity_path: [
        type: :string,
        doc: """
        Where in the response to find resulting entities. Can be overridden per endpoint.
        """
      ],
      base_paginator: [
        type:
          {:spark_behaviour, AshJsonApiWrapper.Paginator, AshJsonApiWrapper.Paginator.Builtins},
        doc: """
        A module implementing the `AshJSonApiWrapper.Paginator` behaviour, to allow scanning pages when reading.
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

  use Spark.Dsl.Extension,
    sections: [@json_api_wrapper],
    transformers: [AshJsonApiWrapper.DataLayer.Transformers.SetEndpointDefaults]

  defmodule Query do
    defstruct [
      :api,
      :request,
      :context,
      :headers,
      :action,
      :limit,
      :offset,
      :filter,
      :runtime_filter,
      :sort,
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

  def can?(
        _,
        {:filter_expr, %Ash.Query.Operator.In{right: %Ash.Query.Ref{}}}
      ),
      do: false

  def can?(
        _,
        {:filter_expr, %Ash.Query.Operator.In{left: %Ash.Query.Ref{}, right: %Ash.Query.Ref{}}}
      ),
      do: false

  def can?(
        _,
        {:filter_expr, %Ash.Query.Operator.In{left: %Ash.Query.Ref{}}}
      ),
      do: true

  def can?(_, :sort), do: true
  def can?(_, {:sort, _}), do: true
  def can?(_, _), do: false

  @impl true
  def resource_to_query(resource) do
    %Query{request: Finch.build(:get, AshJsonApiWrapper.DataLayer.Info.endpoint_base(resource))}
  end

  @impl true
  def filter(query, filter, resource) do
    if filter == false || match?(%Ash.Filter{expression: false}, filter) do
      %{query | override_results: []}
    else
      if filter == nil || filter == true || match?(%Ash.Filter{expression: nil}, filter) do
        {:ok, %{query | filter: filter}}
      else
        if query.action do
          case validate_filter(filter, resource, query.action) do
            {:ok, {endpoint, templates, instructions}, remaining_filter} ->
              {instructions, templates} =
                if templates && !Enum.empty?(templates) do
                  {templates, instructions}
                else
                  instructions =
                    instructions
                    |> Enum.reduce([], fn
                      {:expand_set, field, values} = instruction, new_instructions ->
                        if Enum.any?(new_instructions, fn
                             {:expand_set, ^field, _other_values} ->
                               true

                             _ ->
                               false
                           end) do
                          Enum.map(new_instructions, fn
                            {:expand_set, ^field, other_values} ->
                              {:expand_set, field,
                               other_values
                               |> MapSet.new()
                               |> MapSet.intersection(MapSet.new(values))
                               |> MapSet.to_list()}

                            other ->
                              other
                          end)
                        else
                          [instruction | new_instructions]
                        end

                      instruction, new_instructions ->
                        [instruction | new_instructions]
                    end)

                  {expand_set, instructions} =
                    Enum.split_with(instructions || [], fn
                      {:expand_set, _, _} ->
                        true

                      _ ->
                        false
                    end)

                  templates =
                    expand_set
                    |> Enum.at(0)
                    |> case do
                      nil ->
                        nil

                      {:expand_set, field, values} ->
                        Enum.map(values, &{:set, field, &1})
                    end

                  {instructions, templates}
                end

              new_query_params =
                Enum.reduce(instructions || [], query.request.query || %{}, fn
                  {:set, field, value}, query ->
                    field =
                      field
                      |> List.wrap()
                      |> Enum.map(&to_string/1)

                    AshJsonApiWrapper.Helpers.put_at_path(query, field, value)

                  {:place_in_list, path, value}, query ->
                    update_in!(query, path, [], &[value | &1])
                end)

              {:ok,
               %{
                 query
                 | endpoint: endpoint,
                   templates: templates,
                   runtime_filter: remaining_filter,
                   request: %{query.request | query: new_query_params}
               }}

            {:error, error} ->
              {:error, error}
          end
        else
          {:ok, %{query | filter: filter}}
        end
      end
    end
  end

  @impl true
  def sort(query, sort, _resource) when sort in [nil, []] do
    {:ok, query}
  end

  def sort(query, sort, _resource) do
    endpoint = query.endpoint

    if endpoint.runtime_sort? do
      {:ok, %{query | sort: sort}}
    else
      {:error, "Sorting is not supported"}
    end
  end

  @impl true
  def set_context(_resource, query, context) do
    params = context[:data_layer][:query_params] || %{}
    headers = Map.to_list(context[:data_layer][:headers] || %{})

    action = context[:action]

    {:ok,
     %{
       query
       | request: %{query.request | query: params, headers: headers},
         api: query.api,
         action: action,
         headers: headers,
         context: context
     }}
  end

  defp validate_filter(filter, resource, action) when filter in [nil, true] do
    {:ok, {AshJsonApiWrapper.DataLayer.Info.endpoint(resource, action.name), nil, []}, filter}
  end

  defp validate_filter(filter, resource, action) do
    case AshJsonApiWrapper.Filter.find_filter_that_uses_get_endpoint(filter, resource, action) do
      {:ok, {remaining_filter, get_endpoint, templates}} ->
        {:ok, {get_endpoint, templates, []}, remaining_filter}

      {:ok, nil} ->
        endpoint = AshJsonApiWrapper.DataLayer.Info.endpoint(resource, action.name)

        case filter_instructions(filter, resource, endpoint) do
          {:ok, instructions, remaining_filter} ->
            {:ok, {endpoint, nil, instructions}, remaining_filter}

          {:error, error} ->
            {:error, error}
        end

      {:error, error} ->
        {:error, error}
    end
  end

  defp filter_instructions(filter, _resource, endpoint) do
    fields =
      endpoint.fields
      |> List.wrap()
      |> Enum.filter(& &1.filter_handler)

    Enum.reduce_while(fields, {:ok, [], filter}, fn field, {:ok, instructions, filter} ->
      result =
        case field.filter_handler do
          :simple ->
            AshJsonApiWrapper.Filter.find_simple_filter(filter, field.name)

          {:simple, path} ->
            case AshJsonApiWrapper.Filter.find_simple_filter(filter, field.name) do
              {:ok, {remaining_filter, new_instructions}} ->
                field_name = field.name

                {:ok,
                 {remaining_filter,
                  Enum.map(new_instructions, fn
                    {:set, ^field_name, value} ->
                      {:set, path, value}

                    {:expand_set, ^field_name, values} ->
                      {:expand_set, path, values}

                    other ->
                      # don't think this is possible
                      other
                  end)}}

              other ->
                other
            end

          {:place_in_list, path} ->
            AshJsonApiWrapper.Filter.find_place_in_list_filter(
              filter,
              field.name,
              path
            )
        end

      case result do
        {:ok, nil} ->
          {:cont, {:ok, instructions, filter}}

        {:ok, {remaining_filter, new_instructions}} ->
          {:cont, {:ok, new_instructions ++ instructions, remaining_filter}}
      end
    end)
    |> case do
      {:ok, instructions, nil} ->
        {:ok, instructions, nil}

      {:ok, instructions, remaining_filter} ->
        {:ok, instructions, remaining_filter}

      {:error, error} ->
        {:error, error}
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
    endpoint = AshJsonApiWrapper.DataLayer.Info.endpoint(resource, changeset.action.name)

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
        field = AshJsonApiWrapper.DataLayer.Info.field(resource, attribute.name)

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
        endpoint.path || AshJsonApiWrapper.DataLayer.Info.endpoint_base(resource),
        [{"Content-Type", "application/json"}, {"Accept", "application/json"}],
        body
      )
      |> Map.put(:query, params)

    with request <- request(request, changeset, resource, endpoint.path),
         {:ok, %{status: status} = response} when status >= 200 and status < 300 <-
           do_request(request, resource),
         {:ok, body} <- Jason.decode(response.body),
         {:ok, entities} <- get_entities(body, endpoint, resource),
         {:ok, processed} <-
           process_entities(entities, resource, endpoint) do
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
    Map.put(body || %{}, key, value)
  end

  defp put_in!(body, [first | rest], value) do
    body
    |> Map.put_new(first, %{})
    |> Map.update!(first, &put_in!(&1, rest, value))
  end

  defp update_in!(body, [key], default, func) do
    body
    |> Kernel.||(%{})
    |> Map.put_new(key, default)
    |> Map.update!(key, func)
  end

  defp update_in!(body, [first | rest], default, func) do
    body
    |> Map.put_new(first, %{})
    |> Map.update!(first, &update_in!(&1, rest, default, func))
  end

  @impl true
  def run_query(query, resource, overridden? \\ false)

  def run_query(%{override_results: results} = query, _resource, _overriden)
      when not is_nil(results) do
    do_sort({:ok, results}, query)
  end

  def run_query(query, resource, overridden?) do
    if query.templates do
      query.templates
      |> Enum.uniq()
      |> Task.async_stream(
        fn template ->
          query = %{
            query
            | request: fill_template(query.request, template),
              templates: nil
          }

          run_query(query, resource, true)
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
      endpoint =
        query.endpoint || AshJsonApiWrapper.DataLayer.Info.endpoint(resource, query.action.name)

      path =
        if overridden? do
          query.request.path
        else
          endpoint.path
        end

      query =
        if query.limit do
          if query.offset && query.offset != 0 do
            Logger.warn(
              "ash_json_api_wrapper does not support limits with offsets yet, and so they will both be applied after."
            )

            query
          else
            case endpoint.limit_with do
              {:param, param} ->
                %{
                  query
                  | request: %{
                      query.request
                      | query: Map.put(query.request.query || %{}, param, query.limit)
                    }
                }

              _ ->
                query
            end
          end
        else
          query
        end

      with request <- request(query.request, query.context, resource, path),
           {:ok, %{status: status} = response} when status >= 200 and status < 300 <-
             do_request(request, resource),
           {:ok, body} <- Jason.decode(response.body),
           {:ok, entities} <- get_entities(body, endpoint, resource, paginate_with: request) do
        entities
        |> limit_offset(query)
        |> process_entities(resource, endpoint)
      else
        {:ok, %{status: status} = response} ->
          {:error,
           "Received status code #{status} in request #{inspect(query.request)}. Response: #{inspect(response)}"}

        other ->
          other
      end
    end
    |> do_sort(query)
    |> runtime_filter(query)
  end

  defp runtime_filter({:ok, results}, query) do
    if not is_nil(query.runtime_filter) do
      Ash.Filter.Runtime.filter_matches(query.api, results, query.runtime_filter)
    else
      {:ok, results}
    end
  end

  defp runtime_filter(other, _) do
    other
  end

  defp do_sort({:ok, results}, %{sort: sort}) when sort not in [nil, []] do
    Ash.Sort.runtime_sort(results, sort)
  end

  defp do_sort(other, _), do: other

  defp fill_template(request, template) do
    template
    |> List.wrap()
    |> Enum.reduce(request, fn
      {key, replacement}, request ->
        %{
          request
          | path: String.replace(request.path, ":#{key}", to_string(replacement))
        }

      {:set, key, value}, request ->
        key =
          key
          |> List.wrap()
          |> Enum.map(&to_string/1)

        %{request | query: AshJsonApiWrapper.Helpers.put_at_path(request.query, key, value)}
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

  defp request(request, query_or_changeset, resource, path) do
    case AshJsonApiWrapper.DataLayer.Info.before_request(resource) do
      {module, opts} ->
        module.call(Map.put(request, :path, path), query_or_changeset, opts)

      nil ->
        request
        |> Map.put(:path, path)
    end
  end

  defp do_request(request, resource) do
    request
    |> encode_query()
    |> encode_body()
    |> log_send()
    |> make_request(AshJsonApiWrapper.DataLayer.Info.finch(resource))
    |> log_resp()
  end

  defp make_request(request, finch) do
    case Finch.request(request, finch) do
      {:ok, %{status: code, headers: headers} = response} when code >= 300 and code < 400 ->
        headers
        # some function to pluck headers
        |> get_header("location")
        |> case do
          nil ->
            {:ok, response}

          location ->
            raise "Following 300+ status code redirects not yet supported, was redirected to #{location}"
        end

      other ->
        other
    end
  end

  defp get_header(headers, name) do
    Enum.find_value(headers, fn {key, value} ->
      if key == name do
        value
      end
    end)
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
    %{request | query: do_encode_query(query)}
  end

  defp encode_query(request), do: request

  defp do_encode_query(query) do
    query
    |> sanitize_for_encoding()
    |> URI.encode_query()
  end

  defp sanitize_for_encoding(value, acc \\ %{}, prefix \\ nil)

  defp sanitize_for_encoding(value, acc, prefix) when is_map(value) do
    value
    |> Enum.reduce(acc, fn {key, value}, acc ->
      new_prefix =
        if prefix do
          prefix <> "[#{key}]"
        else
          to_string(key)
        end

      sanitize_for_encoding(value, acc, new_prefix)
    end)
  end

  defp sanitize_for_encoding(value, acc, prefix) when is_list(value) do
    value
    |> Enum.with_index()
    |> Map.new(fn {value, index} ->
      {to_string(index), sanitize_for_encoding(value)}
    end)
    |> sanitize_for_encoding(acc, prefix)
  end

  defp sanitize_for_encoding(value, _acc, nil), do: value
  defp sanitize_for_encoding(value, acc, prefix), do: Map.put(acc, prefix, value)

  defp encode_body(%{body: body} = request) when is_map(body) do
    %{request | body: Jason.encode!(body)}
  end

  defp encode_body(request), do: request

  defp process_entities(entities, resource, endpoint) do
    Enum.reduce_while(entities, {:ok, []}, fn entity, {:ok, entities} ->
      case process_entity(entity, resource, endpoint) do
        {:ok, entity} -> {:cont, {:ok, [entity | entities]}}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, entities} -> {:ok, Enum.reverse(entities)}
      {:error, error} -> {:error, error}
    end
  end

  defp process_entity(entity, resource, endpoint) do
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
        case get_field(entity, attr, resource, endpoint) do
          {:ok, value} ->
            {:cont, {:ok, Map.put(record, attr.name, value)}}

          {:error, error} ->
            {:halt, {:error, error}}
        end
      end
    )
  end

  defp get_field(entity, attr, resource, endpoint) do
    raw_value = get_raw_value(entity, attr, resource, endpoint)

    case Ash.Type.cast_stored(attr.type, raw_value, attr.constraints) do
      {:ok, value} ->
        {:ok, value}

      _ ->
        {:error,
         AshJsonApiWrapper.Errors.InvalidData.exception(field: attr.name, value: raw_value)}
    end
  end

  defp get_raw_value(entity, attr, resource, endpoint) do
    case get_field(resource, endpoint, attr.name) do
      %{path: ""} ->
        entity

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

  defp get_entities(body, endpoint, resource, opts \\ []) do
    if opts[:paginate_with] && endpoint.paginator do
      with {:ok, entities} <-
             get_entities(body, endpoint, resource, Keyword.delete(opts, :paginate_with)),
           {:ok, bodies} <-
             get_all_bodies(
               body,
               endpoint,
               resource,
               opts[:paginate_with],
               &get_entities(&1, endpoint, resource, Keyword.delete(opts, :paginate_with)),
               [entities]
             ) do
        {:ok, bodies |> Enum.reverse() |> List.flatten()}
      end
    else
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

  defp get_all_bodies(
         body,
         %{paginator: {module, opts}} = endpoint,
         resource,
         request,
         entity_callback,
         bodies
       ) do
    case module.continue(body, Enum.at(bodies, 0), request, opts) do
      :halt ->
        {:ok, bodies}

      {:ok, instructions} ->
        request = apply_instructions(request, instructions)

        case do_request(request, resource) do
          {:ok, %{status: status} = response} when status >= 200 and status < 300 ->
            with {:ok, new_body} <- Jason.decode(response.body),
                 {:ok, entities} <- entity_callback.(new_body) do
              get_all_bodies(new_body, endpoint, resource, request, entity_callback, [
                entities | bodies
              ])
            end

          {:ok, %{status: status} = response} ->
            {:error,
             "Received status code #{status} in request #{inspect(request)}. Response: #{inspect(response)}"}

          {:error, error} ->
            {:error, error}
        end
    end
  end

  defp apply_instructions(request, instructions) do
    request
    |> apply_params(instructions)
    |> apply_headers(instructions)
  end

  defp apply_params(request, %{params: params}) when is_map(params) do
    %{request | query: Ash.Helpers.deep_merge_maps(request.query || %{}, params)}
  end

  defp apply_params(request, _), do: request

  defp apply_headers(request, %{headers: headers}) when is_map(headers) do
    %{
      request
      | headers:
          request.headers
          |> Kernel.||(%{})
          |> Map.new()
          |> Map.merge(headers)
          |> Map.to_list()
    }
  end

  defp apply_headers(request, _), do: request

  defp get_field(resource, endpoint, field) do
    Enum.find(endpoint.fields || [], &(&1.name == field)) ||
      Enum.find(AshJsonApiWrapper.DataLayer.Info.fields(resource), &(&1.name == field))
  end
end
