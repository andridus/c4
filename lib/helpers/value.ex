defmodule C4.Value do
  @moduledoc """
    C4.Value
  """
  def insert(_scope, _fields, _value, _idx \\ nil)
  def insert(nil, [], _value, _idx), do: nil

  def insert(nil, fields, value, _idx) do
    fields
    |> Enum.reverse()
    |> Enum.reduce(value, fn field, acc -> Map.put(%{}, field, acc) end)
  end

  def insert(_scope, [], value, _idx), do: value
  def insert([], _fields, _value, _idx), do: []

  def insert({scope, status}, fields, value, idx) do
    {insert(scope, fields, value, idx), status}
  end

  def insert([{idx, scope} | tail], fields, value, idx) do
    [{idx, insert(scope, fields, value)} | insert(tail, fields, value, idx)]
  end

  def insert([{key, scope} | tail], fields, value, idx) do
    [{key, scope} | insert(tail, fields, value, idx)]
  end

  def insert(scope, field, value, idx) when is_bitstring(field),
    do: insert(scope, String.split(field, "."), value, idx)

  def insert(scope, [field | []], value, _idx) do
    get_type(field)
    |> case do
      {:string, field} ->
        existing_key(scope, field)
        |> case do
          {field, :exists} ->
            Map.get(scope, field)
            |> maybe_merge(value, scope, field)

          {field, :new} ->
            Map.put(scope, field, value)
        end

      _ ->
        scope
    end
  end

  def insert(scope, [field | tail], value, idx_r) do
    get_type(field)
    |> case do
      {:string, field} ->
        {field, _} = existing_key(scope, field)

        scope_deep =
          get_scope(scope, field)
          |> insert(tail, value, idx_r)

        Map.get(scope, field)
        |> maybe_merge(scope_deep, scope, field)

      {:array, field} ->
        {field, _} = existing_key(scope, field)

        get_scope(scope, field)
        |> insert(tail, value, idx_r)

      {:array, field, "@"} ->
        {field, _} = existing_key(scope, field)
        scope_deep = get_scope(scope, field)

        scoped =
          if is_list(value) do
            value
            |> Flow.from_enumerable(max_demand: 25)
            |> Flow.map(fn {idx, item} ->
              {idx, scope_deep |> Enum.at(idx) |> insert(tail, item, idx_r)}
            end)
            |> Flow.partition()
            |> Flow.reduce(fn -> [] end, fn item, acc -> acc ++ [item] end)
            |> Enum.to_list()
            |> Enum.sort_by(&elem(&1, 0))
            |> Enum.map(&elem(&1, 1))
          else
            scope_deep
            |> Enum.map(&insert(&1, tail, value, idx_r))
          end

        Map.replace(scope, field, scoped)

      {:array, field, index} ->
        {field, _} = existing_key(scope, field)
        scope_deep = get_scope(scope, field)

        row =
          scope_deep
          |> Enum.at(index)
          |> insert(tail, value, idx_r)

        scoped = scope_deep |> List.replace_at(index, row)
        Map.replace(scope, field, scoped)
    end
  end

  defp maybe_merge(nil, value, scope, field), do: Map.put(scope, field, value)
  defp maybe_merge(_value1, nil, scope, field), do: Map.put(scope, field, "not find field to map")

  defp maybe_merge(value1, value2, scope, field) when is_map(value1) and is_map(value2) do
    value3 = Map.merge(value1, value2)
    Map.put(scope, field, value3)
  end

  defp maybe_merge(value1, value2, scope, field) when is_list(value1) do
    Map.replace(scope, field, value2)
  end

  defp maybe_merge(_value1, value2, scope, field) do
    Map.put(scope, field, value2)
  end

  def replace(string, search, value, scope) do
    Map.get(scope, :response)
    # value = Parse.get_from(value, scope)
    String.replace(string, search, "#{value}")
  end

  def get(_scope, _locate, _default \\ nil)
  def get(_scope, nil, default), do: default
  def get(nil, [], default), do: default
  def get(scope, [], _default), do: scope
  def get(scope, field, default) when is_atom(field), do: get(scope, "#{field}", default)

  def get(scope, fields, default) when is_bitstring(fields) do
    if String.starts_with?(fields, "^") do
      String.replace(fields, "^", "")
    else
      get(scope, fields |> String.split("."), default)
    end
  end

  def get(scope, [field | tail], default) do
    get_type(field)
    |> case do
      {:string, field} ->
        get_scope(scope, field)
        |> get(tail, default)

      {:array, field} ->
        get_scope(scope, field)
        |> get(tail, default)

      {:array, field, index} ->
        get_scope(scope, field)
        |> Enum.at(index)
        |> get(tail, default)

        # call_function(scope, locate_field, insert_field, scope_field, service, function)
    end
  end

  def get(_scope, value, _default), do: value

  def get_scope({_idx, scope}, field) do
    get_scope(scope, field)
  end

  def get_scope(scope, field) when is_map(scope) do
    get_value_from_field(scope, field)
  end

  def get_scope(scope, field) when is_list(scope) do
    scope |> Enum.map(&get_scope(&1, field))
  end

  def get_scope(scope, _field) when is_tuple(scope) do
    :invalid_data
  end

  def get_scope(scope, field), do: get_value_from_field(scope, field)

  defp get_value_from_field(scope, field) when is_map(scope) do
    case existing_key(scope, field) do
      {field, :exists} ->
        Map.get(scope, field)

      {_field, :new} ->
        nil
    end
  end

  defp get_value_from_field(_scope, _field), do: nil

  defp existing_key(scope, field) do
    if Map.has_key?(scope, field) do
      {field, :exists}
    else
      try do
        field_atom = String.to_existing_atom(field)

        if Map.has_key?(scope, field_atom) do
          {field_atom, :exists}
        else
          {field, :new}
        end
      rescue
        _ -> {field, :new}
      end
    end
  end

  defp get_type(param) do
    param = param |> to_string()

    Regex.run(~r/\[(\d)?(\W)?\]/, param)
    |> case do
      nil ->
        {:string, param}

      [x] ->
        {:array, String.replace(param, x, "")}

      [x, _, "@"] ->
        {:array, String.replace(param, x, ""), "@"}

      [x, num] ->
        {:array, String.replace(param, x, ""), String.to_integer(num)}
    end
  end

  def parse_from_item(item, type, field, value) do
    field = String.to_atom(field)

    case type do
      "boolean" ->
        C4.Helpers.convert(value, :bool)

      "deselect" ->
        nil

      "select-multiple" ->
        tail = C4.Value.get(item, field) || []
        Enum.uniq([value | tail])

      "remove-multiple" ->
        tail = C4.Value.get(item, field) || []
        Enum.filter(tail, fn x -> x != value end)

      _ ->
        value
    end
  end
end
