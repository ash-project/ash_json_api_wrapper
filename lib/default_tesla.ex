defmodule AshJsonApiWrapper.DefaultTesla do
  use Tesla

  plug(Tesla.Middleware.FollowRedirects)
end
