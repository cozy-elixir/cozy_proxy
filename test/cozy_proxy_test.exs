defmodule CozyProxyTest do
  use ExUnit.Case
  doctest CozyProxy

  test "greets the world" do
    assert CozyProxy.hello() == :world
  end
end
