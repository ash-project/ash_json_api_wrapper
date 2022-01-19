defmodule AshJsonApiWrapper.Filter do
  @moduledoc false

  def find_simple_filter(
        filter,
        field,
        context \\ %{in_an_or?: false, other_branch_instructions: nil}
      )

  def find_simple_filter(%Ash.Filter{expression: expression}, field, context) do
    find_simple_filter(expression, field, context)
  end

  def find_simple_filter(
        %Ash.Query.BooleanExpression{op: op, left: left, right: right} = expr,
        field,
        context
      ) do
    case find_simple_filter(left, field, context) do
      {:ok, nil} ->
        case find_simple_filter(right, field, context) do
          {:ok, nil} ->
            {:ok, expr, []}

          {:ok, {right_remaining, right_instructions}} ->
            {:ok, Ash.Query.BooleanExpression.new(op, left, right_remaining), right_instructions}
        end

      {:ok, {left_remaining, left_instructions}} ->
        case find_simple_filter(right, field, %{
               context
               | other_branch_instructions: left_instructions
             }) do
          {:ok, nil} ->
            {:ok, {Ash.Query.BooleanExpression.new(op, left_remaining, right), left_instructions}}

          {:ok, {right_remaining, right_instructions}} ->
            {:ok,
             {Ash.Query.BooleanExpression.new(op, left_remaining, right_remaining),
              left_instructions ++ right_instructions}}

          {:error, error} ->
            {:error, error}
        end
    end
  end

  def find_simple_filter(
        %Ash.Query.Operator.Eq{left: left, right: %Ash.Query.Ref{} = right} = op,
        field,
        context
      ) do
    find_simple_filter(%{op | right: left, left: right}, field, context)
  end

  def find_simple_filter(
        %Ash.Query.Operator.Eq{
          left: %Ash.Query.Ref{relationship_path: [], attribute: %{name: name}}
        },
        field,
        _context
      )
      when name != field do
    {:ok, nil}
  end

  def find_simple_filter(
        %Ash.Query.Operator.Eq{
          left: %Ash.Query.Ref{relationship_path: [], attribute: %{name: field}},
          right: value
        },
        field,
        context
      ) do
    if Enum.any?(context.other_branch_instructions, fn
         {:simple, other_field, other_value} ->
           other_field == field && other_value != value

         _ ->
           false
       end) do
      {:error, "Would set a simple filter for #{field} with two different values"}
    else
      {:ok, {nil, [{:set, field, value}]}}
    end
  end

  def find_place_in_list_filter(
        filter,
        field,
        path,
        context \\ %{in_an_or?: false, other_branch_instructions: nil}
      )

  def find_place_in_list_filter(nil, _, _, _), do: {:ok, nil}

  def find_place_in_list_filter(%Ash.Filter{expression: expression}, field, path, context) do
    find_place_in_list_filter(expression, field, path, context)
  end

  def find_place_in_list_filter(
        %Ash.Query.BooleanExpression{op: op, left: left, right: right} = expr,
        field,
        path,
        context
      ) do
    case find_place_in_list_filter(left, field, path, context) do
      {:ok, nil} ->
        case find_place_in_list_filter(right, field, path, context) do
          {:ok, nil} ->
            {:ok, expr, []}

          {:ok, {right_remaining, right_instructions}} ->
            {:ok, Ash.Query.BooleanExpression.new(op, left, right_remaining), right_instructions}
        end

      {:ok, {left_remaining, left_instructions}} ->
        case find_place_in_list_filter(right, field, path, %{
               context
               | other_branch_instructions: left_instructions
             }) do
          {:ok, nil} ->
            {:ok, {Ash.Query.BooleanExpression.new(op, left_remaining, right), left_instructions}}

          {:ok, {right_remaining, right_instructions}} ->
            {:ok,
             {Ash.Query.BooleanExpression.new(op, left_remaining, right_remaining),
              left_instructions ++ right_instructions}}
        end
    end
  end

  def find_place_in_list_filter(
        %Ash.Query.Operator.Eq{left: left, right: %Ash.Query.Ref{} = right} = op,
        field,
        path,
        context
      ) do
    find_place_in_list_filter(%{op | right: left, left: right}, field, path, context)
  end

  def find_place_in_list_filter(
        %Ash.Query.Operator.In{left: left, right: %Ash.Query.Ref{} = right} = op,
        field,
        path,
        context
      ) do
    find_place_in_list_filter(%{op | right: left, left: right}, field, path, context)
  end

  def find_place_in_list_filter(
        %Ash.Query.Operator.Eq{
          left: %Ash.Query.Ref{relationship_path: [], attribute: %{name: name}}
        },
        field,
        _path,
        _context
      )
      when name != field do
    {:ok, nil}
  end

  def find_place_in_list_filter(
        %Ash.Query.Operator.In{
          left: %Ash.Query.Ref{relationship_path: [], attribute: %{name: name}}
        },
        field,
        _path,
        _context
      )
      when name != field do
    {:ok, nil}
  end

  def find_place_in_list_filter(
        %Ash.Query.Operator.Eq{
          left: %Ash.Query.Ref{relationship_path: [], attribute: %{name: field}},
          right: value
        },
        field,
        path,
        _context
      ) do
    {:ok, {nil, [{:place_in_list, path, value}]}}
  end

  def find_place_in_list_filter(
        %Ash.Query.Operator.In{
          left: %Ash.Query.Ref{relationship_path: [], attribute: %{name: field}},
          right: values
        },
        field,
        path,
        _context
      ) do
    {:ok, {nil, Enum.map(values, &{:place_in_list, path, &1})}}
  end

  def find_filter_that_uses_get_endpoint(
        expr,
        resource,
        action,
        templates \\ nil,
        in_an_or? \\ false,
        uses_endpoint \\ nil
      )

  def find_filter_that_uses_get_endpoint(
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

  def find_filter_that_uses_get_endpoint(
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
                  uses_endpoint, add_templates([left_templates, right_templates, templates])}}
              end

            {:ok, nil} ->
              {:ok,
               {Ash.Query.BooleanExpression.new(:and, left_remaining, right), uses_endpoint,
                add_templates([left_templates, templates])}}

            {:error, error} ->
              {:error, error}
          end
        end

      {:ok, nil} ->
        case find_filter_that_uses_get_endpoint(right, resource, action, templates, in_an_or?) do
          {:ok, {right_remaining, get_endpoint, right_templates}} ->
            if uses_endpoint && get_endpoint != uses_endpoint do
              {:error,
               "Filter would cause the usage of different endpoints: #{inspect(uses_endpoint)} and #{inspect(get_endpoint)}"}
            else
              {:ok,
               {Ash.Query.BooleanExpression.new(:and, left, right_remaining), uses_endpoint,
                add_templates([right_templates, templates])}}
            end
        end

      {:error, error} ->
        {:error, error}
    end
  end

  def find_filter_that_uses_get_endpoint(
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
            {:ok, {expr, uses_endpoint, nil}}

          {:error, error} ->
            {:error, error}
        end

      {:error, error} ->
        {:error, error}

      _ ->
        raise "Unreachable!"
    end
  end

  def find_filter_that_uses_get_endpoint(
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

  def find_filter_that_uses_get_endpoint(
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

  def find_filter_that_uses_get_endpoint(
        %Ash.Query.Operator.In{
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

  def find_filter_that_uses_get_endpoint(
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
            {:ok, {nil, get_endpoint, add_templates([[{attribute.name, value}], templates])}}
          end
        end
    end
  end

  def find_filter_that_uses_get_endpoint(
        %Ash.Query.Operator.In{
          left: %Ash.Query.Ref{relationship_path: [], attribute: attribute},
          right: values
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
            {:ok,
             {nil, get_endpoint,
              add_templates([Enum.map(values, &{attribute.name, &1}), templates])}}
          end
        end
    end
  end

  defp add_templates(templates) do
    if Enum.all?(templates, &is_nil/1) do
      nil
    else
      Enum.flat_map(templates, &List.wrap/1)
    end
  end
end
