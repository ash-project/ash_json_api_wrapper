defmodule AshJsonApiWrapper.OpenApi.ResourceGenerator do
  @moduledoc "Generates resources from an open api specification"

  # sobelow_skip ["DOS.StringToAtom"]
  def generate(json, domain, main_config) do
    main_config[:resources]
    |> Enum.map(fn {resource, config} ->
      endpoints =
        json
        |> operations(config)
        |> Enum.map_join("\n\n", fn {path, _method, operation} ->
          entity_path =
            if config[:entity_path] do
              "entity_path \"#{config[:entity_path]}\""
            end

          """
          endpoint :#{operation_id(operation)} do
            path "#{path}"
            #{entity_path}
          end
          """
        end)

      actions =
        json
        |> operations(config)
        |> Enum.map_join("\n\n", fn
          {_path, "get", config} ->
            """
            read :#{operation_id(config)}
            """

          {_path, "post", config} ->
            """
            create :#{operation_id(config)}
            """
        end)

      fields =
        config[:fields]
        |> Enum.map_join("\n\n", fn {name, field_config} ->
          filter_handler =
            if field_config[:filter_handler] do
              "filter_handler #{inspect(field_config[:filter_handler])}"
            end

          """
          field #{inspect(name)} do
            #{filter_handler}
          end
          """
        end)
        |> case do
          "" ->
            ""

          other ->
            """
            fields do
              #{other}
            end
            """
        end

      {:ok, [object]} =
        json
        |> ExJSONPath.eval(config[:object_type])

      attributes =
        object
        |> Map.get("properties")
        |> Enum.map(fn {name, config} ->
          {Macro.underscore(name), config}
        end)
        |> Enum.sort_by(fn {name, _} ->
          name not in List.wrap(config[:primary_key])
        end)
        |> Enum.map_join("\n\n", fn {name, property} ->
          type =
            case property do
              %{"enum" => _values} ->
                ":atom"

              %{"format" => "date-time"} ->
                ":utc_datetime"

              %{"type" => "string"} ->
                ":string"

              %{"type" => "integer"} ->
                ":integer"

              %{"type" => "boolean"} ->
                ":boolean"

              other ->
                raise "Unsupported property: #{inspect(other)}"
            end

          constraints =
            case property do
              %{"enum" => values} ->
                "one_of: #{inspect(Enum.map(values, &String.to_atom/1))}"

              %{"maxLength" => max, "minLength" => min, "type" => "string"} ->
                "min_length: #{min}, max_length: #{max}"

              %{"maxLength" => max, "type" => "string"} ->
                "max_length: #{max}"

              %{"minLength" => min, "type" => "string"} ->
                "min_length: #{min}"

              _ ->
                nil
            end

          primary_key? = name in List.wrap(config[:primary_key])

          if constraints || primary_key? do
            constraints =
              if constraints do
                "constraints #{constraints}"
              end

            primary_key =
              if primary_key? do
                """
                primary_key? true
                allow_nil? false
                """
              end

            """
            attribute :#{name}, #{type} do
              #{primary_key}
              #{constraints}
            end
            """
          else
            """
            attribute :#{name}, #{type}
            """
          end
        end)

      tesla =
        if main_config[:tesla] do
          "tesla #{main_config[:tesla]}"
        end

      endpoint =
        if main_config[:endpoint] do
          "base \"#{main_config[:endpoint]}\""
        end

      code =
        """
        defmodule #{resource} do
          use Ash.Resource, domain: #{inspect(domain)}, data_layer: AshJsonApiWrapper.DataLayer

          json_api_wrapper do
            #{tesla}

            endpoints do
              #{endpoint}
              #{endpoints}
            end

            #{fields}
          end

          actions do
            #{actions}
          end

          attributes do
            #{attributes}
          end
        end
        """
        |> Code.format_string!()
        |> IO.iodata_to_binary()

      {resource, code}
    end)
  end

  defp operation_id(%{"operationId" => operationId}) do
    operationId
    |> Macro.underscore()
  end

  defp operations(json, config) do
    json["paths"]
    |> Enum.filter(fn {path, _value} ->
      String.starts_with?(path, config[:path])
    end)
    |> Enum.flat_map(fn {path, methods} ->
      Enum.map(methods, fn {method, config} ->
        {path, method, config}
      end)
    end)
    |> Enum.filter(fn {_path, method, _config} ->
      method in ["get", "post"]
    end)
  end
end
