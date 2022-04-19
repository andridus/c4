defmodule C4.Api do
  @moduledoc false
  alias C4.Helpers

  defmacro __using__(_) do
    quote do
      import Ecto.Query
      import C4.Api

      def schema do
        @schema
      end

      def changeset(changeset, params, type \\ "create") do
        apply(schema(), :"changeset_#{type}", [changeset, params])
      end

      def json_fields(append) do
        schema().json() ++ append
      end

      def get_by(id, params \\ [where: [], order: [asc: :inserted_at]]) do
        get_by!(params)
        |> case do
          nil -> {:error, :not_found}
          data -> {:ok, data}
        end
      end

      def get_by!(params \\ [where: [], order: [asc: :inserted_at]]) do
        params
        |> default_params()
        |> repo().one()
      end

      def get(id, params \\ [where: [], order: [asc: :inserted_at]]) do
        get!(id, params)
        |> case do
          nil -> {:error, :not_found}
          {:ok, data} -> {:ok, data}
        end
      end

      def get!(id, params \\ [where: [], order: [asc: :inserted_at]]) do
        params
        |> default_params()
        |> repo().get(id)
      end

      def blank() do
        struct(schema())
      end

      def all(params \\ [where: [], order: []]) do
        params
        |> default_params()
        |> repo().all()
      end

      def insert(%Ecto.Changeset{} = model) do
        model |> repo().insert()
      end
      def insert(params) do
        schema()
        |> struct()
        |> schema().changeset_insert(params)
        |> repo().insert()
      end

      

      def update(%Ecto.Changeset{} = model) do
        model |> repo().update()
      end
      def update(%{id: id} = model) do
        params = Map.drop(model, [:id])

        id
        |> get()
        |> schema().changeset_update(params)
        |> repo().update()
      end

      



      def delete(id) when is_bitstring(id) do
        id
        |> get!()
        |> delete()
      end

      def delete(model) do
        model
        |> repo().delete()
      end

      def default_params(params) do
        params
        |> Enum.reduce(schema(), fn
          {:where, params}, sch ->
            params =
              Enum.reduce(params, sch, fn
                {{:ilike, key}, value}, sch ->
                  value = "%#{value}%"
                  sch |> where([p], ilike(field(p, ^key), ^value))

                {key, nil}, sch ->
                  sch |> where([p], is_nil(field(p, ^key)))

                x, sch ->
                  sch |> where(^Keyword.new([x]))
              end)

          {:order, params}, sch ->
            sch |> order_by(^params)

          {:preload, params}, sch ->
            sch |> preload(^params)

          {:limit, params}, sch ->
            sch |> limit(^params)

          {:offset, params}, sch ->
            sch |> offset(^params)

          _, sch ->
            sch
        end)
      end

      def count(params \\ []) do
        params
        |> default_params()
        |> repo().aggregate(:count, :id)
      end

      @doc """
        get json data
      """
      def json(_model, _include \\ [])
      def json(nil, _), do: nil

      def json(model, include) do
        model
        |> preload_json(include)
        |> Map.take(json_fields(include))
      end

      def insert_or_update(%{id: id} = model) when not is_nil(id), do: update(model)
      def insert_or_update(model), do: insert(model)

      defoverridable changeset: 2,
                     changeset: 3,
                     json_fields: 1,
                     get: 1,
                     get: 2,
                     get_by: 1,
                     all: 1,
                     insert: 1,
                     update: 1,
                     delete: 1,
                     json: 2,
                     count: 1
    end
  end

  def repo do
    C4.repo()
  end

  def preload_json(model, include \\ []) do
    includes =
      model
      |> repo().preload(include)
      |> Map.take(include)
      |> Map.to_list()
      |> Enum.map(fn {key, value} ->
        module = get_module(model, key, include)

        if is_list(value) do
          {key, Enum.map(value, &(apply(module, :json, [&1]) |> Helpers.unwrap()))}
        else
          {key, apply(module, :json, [value]) |> Helpers.unwrap()}
        end
      end)
      |> Map.new()

    Map.merge(model, includes)
  end

  def get_module(model, key, _includes) do
    Ecto.build_assoc(model, key, %{})
    |> Map.get(:__struct__)
    |> to_string()
    |> String.replace("Schema", "Api")
    |> Helpers.atomize()
  end

  ########################
end
