# SPDX-FileCopyrightText: 2020 Zach Daniel
#
# SPDX-License-Identifier: MIT

defmodule AshJsonApiWrapper.DefaultTesla do
  @moduledoc """
  A bare bones tesla implementation used by default if one is not provided.
  """

  use Tesla

  plug(Tesla.Middleware.FollowRedirects)
end
