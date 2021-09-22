defmodule CoreTest do
   use ExUnit.Case, async: true
  doctest Core

  test "greets the world" do
    assert Core.hello() == :world
  end
end
