# SPDX-FileCopyrightText: 2021 ash_json_api_wrapper contributors <https://github.com/ash-project/ash_json_api_wrapper/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshJsonApiWrapper.Paginator.Builtins do
  @moduledoc "Builtin paginators"

  @spec continuation_property(String.t(), opts :: Keyword.t()) ::
          AshJsonApiWrapper.Paginator.ref()
  def continuation_property(get, opts) do
    {AshJsonApiWrapper.Paginator.ContinuationProperty, Keyword.put(opts, :get, get)}
  end
end
