defmodule C4.Helpers.Module do
  @moduledoc false
  def concat(module_name, core) when is_atom(module_name) do
    Module.concat([core, module_name])
    |> to_string()
    |> String.replace("C4.Core.C4.Core", "C4.Core")
    |> String.to_atom()
  end

  def concat(module_name, _core) do
    [Macro.camelize(module_name)]
    |> Module.concat()
    |> to_string()
    |> String.replace("C4.Core.C4.Core", "C4.Core")
    |> String.to_atom()
  end

  def api(module_name)
  def api(module_name) when is_atom(module_name), do: api(to_string(module_name))

  def api(module_name) do
    module_name
    |> String.replace("Schema", "Api")
    |> String.to_atom()
  end
end
