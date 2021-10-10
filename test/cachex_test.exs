defmodule CachexTest do
  use ExUnit.Case
  doctest Cachex

  test "greets the world" do
    assert Cachex.hello() == :world
  end
end
