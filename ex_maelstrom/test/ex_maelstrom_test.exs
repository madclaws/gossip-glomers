defmodule ExMaelstromTest do
  use ExUnit.Case
  doctest ExMaelstrom

  test "greets the world" do
    assert ExMaelstrom.hello() == :world
  end
end
