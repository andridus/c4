defmodule C4.Schema do
  @moduledoc false
  @live_opts [:required, :set_once, :to_json, :label, :opts]
  @relation_opts @live_opts ++
                   [
                     :show,
                     :show_in_form,
                     :parent_field,
                     :form,
                     :options,
                     :class,
                     :relation,
                     :default,
                     :schema
                   ]
  defmacro __using__(_) do
    quote do
      use Ecto.Schema
      @behaviour Access
      Module.register_attribute(__MODULE__, :live_fields, accumulate: true)
      Module.register_attribute(__MODULE__, :custom_opts, [])
      Module.register_attribute(__MODULE__, :tabs, accumulate: true)
      Module.register_attribute(__MODULE__, :fields_to_json, accumulate: true)
      Module.register_attribute(__MODULE__, :required_fields, accumulate: true)
      Module.register_attribute(__MODULE__, :update_fields, accumulate: true)
      Module.register_attribute(__MODULE__, :unique_fields, accumulate: true)

      import Ecto.Changeset
      import C4.Schema

      alias C4.Utils

      @before_compile C4.Schema
      @primary_key {:id, :binary_id, autogenerate: true}
      @foreign_key_type :binary_id

      # Structs by default do not implement this. It's easy to delegate this to the Map implementation however.
      defdelegate get(coin, key, default), to: Map
      defdelegate fetch(coin, key), to: Map
      defdelegate get_and_update(coin, key, func), to: Map
      defdelegate pop(coin, key), to: Map

      defimpl Phoenix.HTML.Safe, for: __MODULE__ do
        def to_iodata(data), do: Map.get(data, :id)
      end

      def tabs_field(), do: tabs_field(__MODULE__)
    end
  end

  defmacro __before_compile__(%{module: _module}) do
    quote do
      defp maybe_apply_opts(model, field), do: maybe_apply_opts(model, field, :private)
      def fields_(), do: @live_fields |> Enum.reverse()
      def fields(), do: @live_fields |> Enum.reverse() |> Enum.map(&elem(&1, 0))
      def custom_opts(), do: @custom_opts
      def json(), do: @fields_to_json |> Enum.reverse() |> Kernel.++([:id])
      def update_fields(), do: @update_fields |> Enum.reverse()
      def required_fields(), do: @required_fields |> Enum.reverse()
      def unique_fields(), do: @unique_fields |> Enum.reverse()
      def tabs(), do: @tabs |> Enum.reverse()

      defp changeset_(model, attrs, :insert) do
        {local_fields, assoc_fields, embed_fields} =
          __MODULE__.fields_()
          |> Enum.reduce({[], [], []}, fn
            {_, :relation_type, _} = item, {fld, assc, embd} -> {fld, [item | assc], embd}
            {_, :embed, _} = item, {fld, assc, embd} -> {fld, assc, [item | embd]}
            item, {fld, assc, embd} -> {[item | fld], assc, embd}
          end)

        assoc_keys = assoc_fields |> Enum.map(&elem(&1, 0))
        embed_keys = embed_fields |> Enum.map(&elem(&1, 0))
        attrs = local_fields |> Enum.reverse() |> precast(attrs)

        flds =
          Enum.reduce(assoc_keys ++ embed_keys, fields(), fn k, acc -> List.delete(acc, k) end)

        rfs =
          required_fields()
          |> Enum.reduce([], fn
            {field, true}, acc ->
              [field | acc]

            {field, [when: opts]}, acc ->
              Enum.reduce(opts, false, fn
                {k, v}, acc -> C4.Value.get(attrs, k) == v
                _, acc -> acc
              end)
              |> if do
                [field | acc]
              else
                acc
              end
          end)

        model =
          model
          |> cast(attrs, flds)
          |> then(fn model ->
            model =
              Enum.reduce(assoc_fields, model, fn {key, a, opt}, model ->
                schema = opt[:schema]
                cast_assoc(model, key, with: &schema.changeset_insert/2)
              end)

            Enum.reduce(embed_fields, model, fn {key, a, opt}, model ->
              schema = opt[:schema]
              cast_embed(model, key, with: &schema.changeset_insert/2)
            end)
          end)
          |> validate_required(rfs)

        model =
          Enum.reduce(unique_fields(), model, fn field, model ->
            unique_constraint(model, field)
          end)

        Enum.reduce(fields_(), model, fn field, model ->
          maybe_apply_opts(model, field)
        end)
      end

      defp changeset_(model, attrs, :update) do
        keys = Map.keys(attrs)

        {local_fields, assoc_fields, embed_fields} =
          __MODULE__.fields_()
          # |> Enum.filter(fn 
          #   {key, _, _} -> 
          #     key in keys 
          #   _ -> false
          # end)
          |> Enum.reduce({[], [], []}, fn
            {_, :relation_type, _} = item, {fld, assc, embd} -> {fld, [item | assc], embd}
            {_, :embed, _} = item, {fld, assc, embd} -> {fld, assc, [item | embd]}
            item, {fld, assc, embd} -> {[item | fld], assc, embd}
          end)

        assoc_keys = assoc_fields |> Enum.map(&elem(&1, 0))
        embed_keys = embed_fields |> Enum.map(&elem(&1, 0))
        attrs = local_fields |> Enum.reverse() |> precast(attrs)

        flds =
          Enum.reduce(assoc_keys ++ embed_keys, fields(), fn k, acc -> List.delete(acc, k) end)

        rfs =
          required_fields()
          |> Enum.reduce([], fn
            {field, true}, acc ->
              [field | acc]

            {field, [when: opts]}, acc ->
              Enum.reduce(opts, false, fn
                {k, v}, acc -> C4.Value.get(attrs, k) == v
                _, acc -> acc
              end)
              |> if do
                [field | acc]
              else
                acc
              end
          end)

        model =
          model
          |> cast(attrs, flds)
          |> then(fn model ->
            Enum.reduce(embed_fields, model, fn {key, a, opt}, model ->
              schema = opt[:schema]
              cast_embed(model, key, with: &schema.changeset_update/2)
            end)
          end)

        model =
          Enum.reduce(unique_fields(), model, fn field, model ->
            unique_constraint(model, field)
          end)

        model =
          Enum.reduce(fields_(), model, fn field, model ->
            maybe_apply_opts(model, field)
          end)
      end
    end
  end

  defmacro many_to_many_(name, queryable, opts \\ []) do
    queryable = expand_alias(queryable, __CALLER__)
    opts = expand_alias_in_key(opts, :join_through, __CALLER__)
    opts = opts ++ [relation: :many_to_many, default: []]
    only_opts = get_opts(opts, @relation_opts)

    quote do
      Module.put_attribute(
        __MODULE__,
        :live_fields,
        {unquote(name), :relation_type, unquote(opts) ++ [schema: unquote(queryable)]}
      )

      field = {:many_to_many, unquote(name), unquote(queryable), unquote(opts)}
      Module.put_attribute(__MODULE__, :tabs, field)

      Ecto.Schema.__many_to_many__(
        __MODULE__,
        unquote(name),
        unquote(queryable),
        unquote(only_opts)
      )
    end
  end

  defmacro belongs_to_(name, queryable, opts \\ []) do
    queryable = expand_alias(queryable, __CALLER__)
    opts = opts ++ [relation: :belongs_to, default: nil]
    only_opts = get_opts(opts, @relation_opts)

    quote do
      Module.put_attribute(
        __MODULE__,
        :live_fields,
        {unquote(name), :relation_type, unquote(opts) ++ [schema: unquote(queryable)]}
      )

      field = {:belongs_to, unquote(name), unquote(queryable), unquote(opts)}
      Module.put_attribute(__MODULE__, :tabs, field)

      Ecto.Schema.__belongs_to__(
        __MODULE__,
        unquote(name),
        unquote(queryable),
        unquote(only_opts)
      )
    end
  end

  defmacro has_one_(name, queryable, opts \\ []) do
    queryable = expand_alias(queryable, __CALLER__)
    opts = opts ++ [relation: :has_one, default: nil]
    only_opts = get_opts(opts, @relation_opts)

    quote do
      Module.put_attribute(
        __MODULE__,
        :live_fields,
        {unquote(name), :relation_type, unquote(opts) ++ [schema: unquote(queryable)]}
      )

      field = {:has_one, unquote(name), unquote(queryable), unquote(opts)}
      Module.put_attribute(__MODULE__, :tabs, field)
      Ecto.Schema.__has_one__(__MODULE__, unquote(name), unquote(queryable), unquote(only_opts))
    end
  end

  defmacro has_many_(name, queryable, opts \\ []) do
    queryable = expand_alias(queryable, __CALLER__)
    opts = opts ++ [relation: :has_many, default: [], schema: queryable]
    only_opts = get_opts(opts, @relation_opts)

    quote do
      Module.put_attribute(
        __MODULE__,
        :live_fields,
        {unquote(name), :relation_type, unquote(opts)}
      )

      field = {:has_many, unquote(name), unquote(queryable), unquote(opts)}
      Module.put_attribute(__MODULE__, :tabs, field)
      Ecto.Schema.__has_many__(__MODULE__, unquote(name), unquote(queryable), unquote(only_opts))
    end
  end

  defmacro embeds_many_(name, queryable, opts \\ []) do
    queryable = expand_alias(queryable, __CALLER__)
    opts = opts ++ [default: [], schema: queryable]
    only_opts = get_opts(opts, @relation_opts)

    quote do
      Module.put_attribute(__MODULE__, :live_fields, {unquote(name), :embed, unquote(opts)})
      field = {:embeds_many, unquote(name), unquote(queryable), unquote(opts)}
      Module.put_attribute(__MODULE__, :tabs, field)

      Ecto.Schema.__embeds_many__(
        __MODULE__,
        unquote(name),
        unquote(queryable),
        unquote(only_opts)
      )
    end
  end

  defmacro embeds_one_(name, queryable, opts \\ []) do
    queryable = expand_alias(queryable, __CALLER__)
    opts = opts ++ [default: nil, schema: queryable]
    only_opts = get_opts(opts, @relation_opts)
    show_in_form = opts[:show_in_form] || false

    quote do
      if unquote(show_in_form),
        do:
          Module.put_attribute(
            __MODULE__,
            :live_fields,
            {unquote(name), :embed, unquote(opts) ++ [schema: unquote(queryable)]}
          )

      field = {:embeds_one, unquote(name), unquote(queryable), unquote(opts)}
      Module.put_attribute(__MODULE__, :tabs, field)

      Ecto.Schema.__embeds_one__(
        __MODULE__,
        unquote(name),
        unquote(queryable),
        unquote(only_opts)
      )
    end
  end

  defmacro custom_opts(opts \\ []) do
    quote do
      Module.put_attribute(__MODULE__, :custom_opts, unquote(opts))
    end
  end

  defmacro field_(name, type \\ :string, opts \\ []),
    do: parse_field_(__CALLER__, name, type, opts)

  def parse_field_(%{module: module}, name, type, opts) do
    only_opts = get_opts(opts)

    quote do
      module = unquote(module)
      name = unquote(name)
      type = unquote(type)
      opts = unquote(opts)

      if opts[:required],
        do: Module.put_attribute(module, :required_fields, {name, opts[:required]})

      if opts[:unique], do: Module.put_attribute(module, :unique_fields, name)
      if !opts[:json], do: Module.put_attribute(module, :fields_to_json, name)

      if is_nil(opts[:update]) || opts[:update] == true,
        do: Module.put_attribute(module, :update_fields, name)

      Module.put_attribute(module, :live_fields, {name, type, opts})

      if !!opts[:relation] == false,
        do: Ecto.Schema.__field__(module, name, type, unquote(only_opts))
    end
  end

  defp get_opts(opts, default \\ @live_opts) do
    Keyword.drop(opts, default)
  end

  def precast(fields, attrs) do
    Enum.reduce(fields, attrs, fn {_field, _type, opts}, attrs ->
      (opts[:precast] || [])
      |> Enum.reduce(attrs, fn
        {module, function, args}, attrs ->
          apply(module, function, [attrs] ++ args)

        _, attrs ->
          attrs
      end)
    end)
  end

  def maybe_apply_opts(model, {field, type, opts}, :private) do
    applies = opts[:applies] || []

    model =
      Enum.reduce(applies, model, fn
        {module, function, args}, model ->
          apply(module, function, [model] ++ args)

        _, model ->
          model
      end)

    validates = opts[:validate] || []

    Enum.reduce(validates, model, fn
      {:format, value}, model ->
        model |> Ecto.Changeset.validate_format(field, value)

      {:function, {module, function}}, model ->
        apply(module, function, [model, field, type])

      _, model ->
        model
    end)
  end

  defp expand_alias({:__aliases__, _, _} = ast, env),
    do: Macro.expand(ast, %{env | function: {:__schema__, 2}})

  defp expand_alias(ast, _env),
    do: ast

  defp expand_alias_in_key(opts, key, env) do
    if is_list(opts) and Keyword.has_key?(opts, key) do
      Keyword.update!(opts, key, &expand_alias(&1, env))
    else
      opts
    end
  end

  def tabs_field(module) do
    [
      %{name: :basic, label: "Básico", schema: module}
      | module.tabs()
        |> Enum.map(&parse_tabs/1)
        |> Enum.filter(&(not is_nil(&1)))
        |> List.flatten()
    ]
  end

  def parse_tabs({relation, name, schema, opts}) do
    with relation when relation not in [:belongs_to] <- relation,
         in_form when is_nil(in_form) <- opts[:show_in_form] do
      label = opts[:label] || name
      schema = opts[:join_through] || schema
      show = if is_nil(opts[:show]), do: :always, else: opts[:show]

      case show do
        false ->
          nil

        _show ->
          opts
          |> Keyword.delete(:join_through)
          |> Map.new()
          |> Map.merge(%{label: label, name: name, schema: schema, relation: relation})
      end
    else
      _e ->
        []
    end
  end

  def get_fields({:many_to_many, field, schema, _opts}) do
    [{field, apply(schema, :fields_, [])}]
  end
end
