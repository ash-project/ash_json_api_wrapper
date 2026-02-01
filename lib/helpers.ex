# SPDX-FileCopyrightText: 2021 ash_json_api_wrapper contributors <https://github.com/ash-project/ash_json_api_wrapper/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshJsonApiWrapper.Helpers do
  @moduledoc false
  def put_at_path(_, [], value), do: value

  def put_at_path(nil, [key | rest], value) do
    %{key => put_at_path(nil, rest, value)}
  end

  def put_at_path(map, [key | rest], value) when is_map(map) do
    map
    |> Map.put_new(key, %{})
    |> Map.update!(key, &put_at_path(&1, rest, value))
  end
end
