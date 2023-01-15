defmodule AshJsonApiWrapper.Paginator.Builtins do
  @moduledoc "Builtin paginators"

  @spec continuation_property(String.t(), opts :: Keyword.t()) ::
          AshJsonApiWrapper.Paginator.ref()
  def continuation_property(get, opts) do
    {AshJsonApiWrapper.Paginator.ContinuationProperty, Keyword.put(opts, :get, get)}
  end
end
