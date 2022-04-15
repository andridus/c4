defmodule C4 do
  def repo do
    Application.get_env(:c4, :repo)
  end
end
