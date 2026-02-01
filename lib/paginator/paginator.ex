# SPDX-FileCopyrightText: 2021 ash_json_api_wrapper contributors <https://github.com/ash-project/ash_json_api_wrapper/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshJsonApiWrapper.Paginator do
  @moduledoc """
  Behavior for scanning pages of a paginated endpoint.
  """

  @type ref :: {module, Keyword.t()}

  defmacro __using__(_) do
    quote do
      @behaviour AshJsonApiWrapper.Paginator
    end
  end

  @callback start(opts :: Keyword.t()) ::
              {:ok, %{optional(:params) => map, optional(:headers) => map}}

  @callback continue(
              response :: term,
              entities :: [Ash.Resource.record()],
              opts :: Keyword.t()
            ) :: {:ok, %{optional(:params) => map, optional(:headers) => map}} | :halt
end
