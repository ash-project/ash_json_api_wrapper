defmodule AshJsonApiWrapperTest do
  use ExUnit.Case
  doctest AshJsonApiWrapper

  test "greets the world" do
    assert AshJsonApiWrapper.hello() == :world
  end
end
