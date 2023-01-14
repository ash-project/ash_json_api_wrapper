defmodule AshJsonApiWrapper.Finch.Plug.Function do
  @moduledoc "Function implementation handler for `AshJsonApiWrapper.Finch`"
  use AshJsonApiWrapper.Finch.Plug

  @impl AshJsonApiWrapper.Finch.Plug
  def call(request, query_or_changeset, fun: {m, f, a}) do
    apply(m, f, [request, query_or_changeset | a])
  end

  def call(request, query_or_changeset, fun: fun) do
    fun.(request, query_or_changeset)
  end
end
