defmodule AshJsonApiWrapper.Finch.Plug do
  defmacro __using__(_) do
    quote do
      @behaviour AshJsonApiWrapper.Finch.Plug
    end
  end

  @type ref :: {module, Keyword.t()}

  @callback call(
              request :: Finch.Request.t(),
              query_or_changeset :: Ash.Changeset.t() | Ash.Query.t(),
              opts :: Keyword.t()
            ) :: Finch.Request.t()
end
