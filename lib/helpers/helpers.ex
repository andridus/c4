defmodule C4.Helpers do
  @moduledoc false
  #### convert function
  def convert(value, :string), do: to_string(value)
  def convert(value, :int) when is_integer(value), do: value
  def convert(value, :int) when is_bitstring(value), do: String.to_integer(value)
  def convert(value, :bool) when value in ["on", "ON", "1", "true", "TRUE", true], do: true
  def convert(_, :bool), do: false
  def convert(value, :boolean) when value in ["on", "ON", "1", "true", "TRUE", true], do: true
  def convert(_, :boolean), do: false
  def convert(_, _), do: nil

  #### maybe function
  def maybe(_value, _optional \\ nil)
  def maybe(nil, opt), do: opt
  def maybe(value, _opt), do: value

  def atomize(string) when is_bitstring(string) do
    string |> String.to_existing_atom()
  rescue
    ArgumentError -> String.to_atom(string)
  end

  def map_to_atom(nil), do: nil
  def map_to_atom([]), do: []
  def map_to_atom(string) when is_bitstring(string), do: string
  def map_to_atom(map) when is_map(map), do: map |> Map.to_list() |> map_to_atom() |> Map.new()
  def map_to_atom([head | list]), do: [map_to_atom(head) | map_to_atom(list)]
  def map_to_atom({key, val}) when is_map(val), do: {atomize(key), map_to_atom(val)}

  def map_to_atom({key, val}) when is_list(val),
    do: {to_string(key), Enum.map(val, &map_to_atom(&1))}

  def map_to_atom({key, val}), do: {atomize(key), val}

  def map_to_string(nil), do: nil
  def map_to_string([]), do: []
  def map_to_string(string) when is_bitstring(string), do: string

  def map_to_string(map) when is_map(map),
    do: map |> Map.to_list() |> map_to_string() |> Map.new()

  def map_to_string([head | list]), do: [map_to_string(head) | map_to_string(list)]
  def map_to_string({key, val}) when is_map(val), do: {to_string(key), map_to_string(val)}

  def map_to_string({key, val}) when is_list(val),
    do: {to_string(key), Enum.map(val, &map_to_string(&1))}

  def map_to_string({key, val}), do: {to_string(key), val}

  def ok(value), do: {:ok, value}
  def unwrap({:ok, value}), do: value
  def unwrap(err), do: err
  def unwrap!({_, value}), do: value

  def update_changes(old_map, new_map) when is_map(new_map) do
    Map.to_list(new_map)
    |> Enum.reduce(old_map, fn
      {key, value}, old_map when is_map(value) ->
        new_deep_map = old_map[key]
        deep_map = update_changes(value, new_deep_map)
        Map.put(old_map, key, deep_map)

      {key, value}, old_map ->
        Map.put(old_map, key, value)
    end)
  end

  def update_changes(old_map, _new_map), do: old_map

  def ellipse(string, len) when is_bitstring(string) do
    strlen = String.length(string)

    if strlen <= len do
      string
    else
      String.slice(string, 0, len) <> "..."
    end
  end

  def ellipse(value, _len), do: value

  def unique(len) do
    gen_rnd(len, "abcdefghijklmnopqrstuvwxyz1234567890")
  end

  defp gen_rnd(to, al) do
    # DateTime.utc_now |> DateTime.to_unix(:millisecond)
    len = String.length(al)
    x = fn _x -> String.at(al, :rand.uniform(len)) end
    1..to |> Enum.map_join(x)
  end
end
