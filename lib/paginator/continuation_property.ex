defmodule AshJsonApiWrapper.Paginator.ContinuationProperty do
  use AshJsonApiWrapper.Paginator

  def continue(_response, [], _, _), do: :halt

  def continue(response, _entities, _request, opts) do
    case ExJSONPath.eval(response, opts[:get]) do
      {:ok, [value | _]} when not is_nil(value) ->
        if opts[:header] do
          {:ok, %{headers: %{opts[:header] => value}}}
        else
          if opts[:param] do
            {:ok,
             %{params: AshJsonApiWrapper.Helpers.put_at_path(%{}, List.wrap(opts[:param]), value)}}
          else
            :halt
          end
        end

      _ ->
        :halt
    end
  end
end
