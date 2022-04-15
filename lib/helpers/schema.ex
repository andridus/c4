defmodule C4.Helpers.Schema do
  @moduledoc false
  # def validate?(data, atom, schema), do: []
  # def validate?([data | tail], schema), do: [validate?(data,schema) | validate?(tail,schema)]
  def validate?(_items, _data, _gettext \\ nil)
  def validate?([], _data, _gettext), do: []

  def validate?(items, data, gettext) do
    data = %{data | errors: %{}}

    items
    |> Enum.reduce([], &[validate_priv(&1, data) | &2])
    |> List.flatten()
    |> Enum.filter(&(elem(&1, 1).valid? == false))
    |> case do
      [] ->
        {:ok, data}

      errors ->
        {:error,
         errors
         |> Enum.map(fn {atom, x} ->
           x.errors |> Enum.map(fn {k, {msg, _}} -> {"#{atom}.#{k}", msg} end)
         end)
         |> List.flatten()
         |> Enum.reduce(data, fn {k, v}, data ->
           value = if is_nil(gettext), do: v, else: Gettext.dgettext(gettext, "errors", v)
           C4.Value.insert(data, "errors.#{k}", value)
         end)}
    end
  end

  defp validate_priv({atom, schema}, data) do
    validate_priv(data, atom, schema, [])
  end

  defp validate_priv({atom, schema, opts}, data) do
    validate_priv(data, atom, schema, opts)
  end

  defp validate_priv(data, atom, schema, opts) do
    when_ = opts[:when] || []

    Enum.reduce(when_, true, fn {key, value}, _acc ->
      C4.Value.get(data, key) == value
    end)
    |> if do
      validate_one(C4.Value.get(data, atom), schema, atom)
    else
      []
    end
  end

  defp validate_one([], _schema, _atom), do: []

  defp validate_one([data | tail], schema, atom),
    do: [validate_one(data, schema, atom) | validate_one(tail, schema, atom)]

  defp validate_one({_idx, data}, schema, atom) do
    {atom, struct(schema) |> schema.changeset_insert(Map.take(data, schema.json()))}
  end

  defp validate_one(data, schema, atom) do
    {atom, struct(schema) |> schema.changeset_insert(Map.take(data, schema.json()))}
  end

  def changeset_insert([], _schema), do: []

  def changeset_insert([data | tail], schema),
    do: [changeset_insert(data, schema) | changeset_insert(tail, schema)]

  def changeset_insert({_idx, data}, schema) do
    struct(schema) |> schema.changeset_insert(Map.take(data, schema.fields()))
  end

  def changeset_insert(data, schema) do
    struct(schema)
    |> schema.changeset_insert(Map.take(data, schema.fields()))
  end

  def changeset_update(_model, [], _schema), do: []

  def changeset_update(model, [data | tail], schema),
    do: [changeset_update(model, data, schema) | changeset_update(model, tail, schema)]

  def changeset_update(model, {_idx, data}, schema) do
    model |> schema.changeset_update(Map.take(data, schema.fields() ++ [:id]))
  end

  def changeset_update(model, data, schema) do
    model
    |> schema.changeset_update(Map.take(data, schema.fields() ++ [:id]))
  end

  def only_attributes([], _schema), do: []

  def only_attributes([{_, data} | tail], schema),
    do: [only_attributes(data, schema) | only_attributes(tail, schema)]

  def only_attributes([data | tail], schema),
    do: [only_attributes(data, schema) | only_attributes(tail, schema)]

  def only_attributes(data, schema) do
    attrs = Map.take(data, schema.fields() ++ [:id]) |> remove_unloaded_assocs()
    C4.Schema.precast(schema.fields_(), attrs)
  end

  def remove_unloaded_assocs(model) do
    model
    |> Map.to_list()
    |> Enum.reduce(
      [],
      fn
        {_k, %Ecto.Association.NotLoaded{}}, acc -> acc
        {_k, _v} = i, acc -> [i | acc]
      end
    )
    |> Map.new()
  end
end
