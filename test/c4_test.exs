defmodule C4Test do
  use ExUnit.Case
  doctest C4

  test "greets the world" do
    assert C4.hello() == :world
  end
end
