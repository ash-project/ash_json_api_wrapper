defmodule AshJsonApiWrapper.DefaultTesla do
  @moduledoc """
  A bare bones tesla implementation used by default if one is not provided.
  """

  use Tesla

  plug(Tesla.Middleware.FollowRedirects)
end
