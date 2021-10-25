defmodule AshApiWrapperTest do
  use ExUnit.Case
  doctest AshApiWrapper

  test "greets the world" do
    assert AshApiWrapper.hello() == :world
  end
end
