# SPDX-FileCopyrightText: 2021 ash_json_api_wrapper contributors <https://github.com/ash-project/ash_json_api_wrapper/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshJsonApiWrapper.DefaultTesla do
  @moduledoc """
  A bare bones tesla implementation used by default if one is not provided.
  """

  use Tesla

  plug(Tesla.Middleware.FollowRedirects)
end
