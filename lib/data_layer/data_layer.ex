defmodule AshJsonApiWrapper.DataLayer do
  @moduledoc """
  A data layer for wrapping external JSON APIs.
  """

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
    identifier: {:auto, :unique_integer},
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
      tesla: [
        type: :atom,
        default: AshJsonApiWrapper.DefaultTesla,
        doc: """
        The Tesla module to use.
        """
      ]
    ]
  }

  require Logger

  use Spark.Dsl.Extension,
    sections: [@json_api_wrapper],
    transformers: [AshJsonApiWrapper.DataLayer.Transformers.SetEndpointDefaults]

  defmodule Query do
    @moduledoc false
    defstruct [
      :api,
      :context,
      :headers,
      :action,
      :limit,
      :offset,
      :filter,
      :runtime_filter,
      :path,
      :query_params,
      :body,
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

  def can?(_, :nested_expressions), do: true

  def can?(_, :sort), do: true
  def can?(_, {:sort, _}), do: true
  def can?(_, _), do: false

  @impl true
  def resource_to_query(resource, api \\ nil) do
    %Query{path: AshJsonApiWrapper.DataLayer.Info.endpoint_base(resource), api: api}
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
              {templates, instructions} =
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

                  {templates, instructions}
                end

              new_query_params =
                Enum.reduce(instructions || [], query.query_params || %{}, fn
                  {:set, field, value}, query ->
                    field =
                      field
                      |> List.wrap()
                      |> Enum.map(&to_string/1)

                    AshJsonApiWrapper.Helpers.put_at_path(query, field, value)

                  {:place_in_list, path, value}, query ->
                    update_in!(query, path, [value], &[value | &1])

                  {:place_in_csv_list, path, value}, query ->
                    update_in!(query, path, "#{value}", &"#{&1},#{value}")
                end)

              {:ok,
               %{
                 query
                 | endpoint: endpoint,
                   templates: templates,
                   runtime_filter: remaining_filter,
                   query_params: new_query_params
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
  def set_context(resource, query, context) do
    params = context[:data_layer][:query_params] || %{}
    headers = Map.to_list(context[:data_layer][:headers] || %{})

    action = context[:action]

    {:ok,
     %{
       query
       | query_params: params,
         headers: headers,
         api: query.api,
         action: action,
         endpoint: AshJsonApiWrapper.DataLayer.Info.endpoint(resource, action.name),
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

  defp filter_instructions(filter, resource, endpoint) do
    fields =
      endpoint.fields
      |> Enum.concat(AshJsonApiWrapper.DataLayer.Info.fields(resource))
      |> Enum.uniq_by(& &1.name)
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
              path,
              :place_in_list
            )

          {:place_in_csv_list, path} ->
            AshJsonApiWrapper.Filter.find_place_in_list_filter(
              filter,
              field.name,
              path,
              :place_in_csv_list
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

    path = endpoint.path || AshJsonApiWrapper.DataLayer.Info.endpoint_base(resource)
    headers = [{"Content-Type", "application/json"}, {"Accept", "application/json"}]

    with {:ok, %{status: status} = response} when status >= 200 and status < 300 <-
           AshJsonApiWrapper.DataLayer.Info.tesla(resource).get(path,
             body: body,
             query: params,
             headers: headers
           ),
         {:ok, body} <- Jason.decode(response.body),
         {:ok, entities} <- get_entities(body, endpoint, resource),
         {:ok, processed} <-
           process_entities(entities, resource, endpoint) do
      {:ok, Enum.at(processed, 0)}
    else
      {:ok, %{status: status} = response} ->
        # TODO: add method/query params
        {:error,
         "Received status code #{status} from GET #{path}. Response: #{inspect(response)}"}

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
    endpoint =
      query.endpoint || AshJsonApiWrapper.DataLayer.Info.endpoint(resource, query.action.name)

    query =
      if overridden? do
        query
      else
        %{query | path: endpoint.path}
      end

    if query.templates do
      query.templates
      |> Enum.uniq()
      |> Task.async_stream(
        fn template ->
          query
          |> fill_template(template)
          |> Map.put(:templates, nil)
          |> run_query(resource, true)
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
      query =
        if query.limit do
          if query.offset && query.offset != 0 do
            Logger.warning(
              "ash_json_api_wrapper does not support limits with offsets yet, and so they will both be applied after."
            )
          end

          case endpoint.limit_with do
            {:param, param} ->
              %{
                query
                | query_params: Map.put(query.query_params || %{}, param, query.limit)
              }

            _ ->
              query
          end
        else
          query
        end

      query =
        if endpoint.paginator do
          %{paginator: {module, opts}} = endpoint
          {:ok, instructions} = module.start(opts)
          apply_instructions(query, instructions)
        else
          query
        end

      with {:ok, %{status: status} = response} when status >= 200 and status < 300 <-
             make_request(resource, query),
           {:ok, body} <- Jason.decode(response.body),
           {:ok, entities} <- get_entities(body, endpoint, resource, paginate_with: query) do
        entities
        |> limit_offset(query)
        |> process_entities(resource, endpoint)
      else
        {:ok, %{status: status} = response} ->
          # TODO: more info here
          {:error,
           "Received status code #{status} from #{query.path}. Response: #{inspect(response)}"}

        other ->
          other
      end
    end
    |> do_sort(query)
    |> runtime_filter(query)
  end

  defp runtime_filter({:ok, results}, query) do
    if is_nil(query.runtime_filter) do
      {:ok, results}
    else
      Ash.Filter.Runtime.filter_matches(query.api, results, query.runtime_filter)
    end
  end

  defp runtime_filter(other, _) do
    other
  end

  defp do_sort({:ok, results}, %{sort: sort}) when sort not in [nil, []] do
    Ash.Sort.runtime_sort(results, sort, [])
  end

  defp do_sort(other, _), do: other

  defp fill_template(query, template) do
    template
    |> List.wrap()
    |> Enum.reduce(query, fn
      {key, replacement}, query ->
        %{
          query
          | path: String.replace(query.path, ":#{key}", to_string(replacement))
        }

      {:set, key, value}, query ->
        key =
          key
          |> List.wrap()
          |> Enum.map(&to_string/1)

        %{
          query
          | query_params: AshJsonApiWrapper.Helpers.put_at_path(query.query_params, key, value)
        }
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

  defp make_request(resource, query) do
    # log_send(path, query)
    # IO.inspect(query.query_params)

    AshJsonApiWrapper.DataLayer.Info.tesla(resource).get(query.path,
      body: query.body,
      query: query.query_params
    )

    # |> log_resp(path, query)
  end

  # defp log_send(request) do
  #   Logger.debug("Sending request: #{inspect(request)}")
  #   request
  # end

  # defp log_resp(response) do
  #   Logger.debug("Received response: #{inspect(response)}")
  #   response
  # end

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
         paginate_with,
         entity_callback,
         bodies
       ) do
    case module.continue(body, Enum.at(bodies, 0), opts) do
      :halt ->
        {:ok, bodies}

      {:ok, instructions} ->
        query = apply_instructions(paginate_with, instructions)

        case make_request(resource, query) do
          {:ok, %{status: status} = response} when status >= 200 and status < 300 ->
            with {:ok, new_body} <- Jason.decode(response.body),
                 {:ok, entities} <- entity_callback.(new_body) do
              get_all_bodies(new_body, endpoint, resource, paginate_with, entity_callback, [
                entities | bodies
              ])
            end

          {:ok, %{status: status} = response} ->
            # TODO: more info
            {:error,
             "Received status code #{status} in #{query.path}. Response: #{inspect(response)}"}

          {:error, error} ->
            {:error, error}
        end
    end
  end

  defp apply_instructions(query, instructions) do
    query
    |> apply_params(instructions)
    |> apply_headers(instructions)
  end

  defp apply_params(query, %{params: params}) when is_map(params) do
    %{query | query_params: Ash.Helpers.deep_merge_maps(query.query_params || %{}, params)}
  end

  defp apply_params(query, _), do: query

  defp apply_headers(query, %{headers: headers}) when is_map(headers) do
    %{
      query
      | headers:
          query.headers
          |> Kernel.||(%{})
          |> Map.new()
          |> Map.merge(headers)
          |> Map.to_list()
    }
  end

  defp apply_headers(query, _), do: query

  defp get_field(resource, endpoint, field) do
    Enum.find(endpoint.fields || [], &(&1.name == field)) ||
      Enum.find(AshJsonApiWrapper.DataLayer.Info.fields(resource), &(&1.name == field))
  end
end
