defmodule AshJsonApiWrapper.Paginator.ContinuationProperty do
  @moduledoc "A paginator that uses a continuation property to paginate"
  use AshJsonApiWrapper.Paginator

  def start(_opts) do
    {:ok, %{}}
  end

  def continue(_response, [], _), do: :halt

  def continue(response, _entities, opts) do
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
