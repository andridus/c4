defmodule C4.Helpers.HandleEvent do
  @moduledoc false
  use C4.Component

  view(do: ~H"..")

  def update_field(
        data,
        %{"type" => type, "remove" => _, "field" => field, "value" => value} = params
      ) do
    case type do
      v when v in ["select_multiple", "tags"] ->
        current_value = C4.Value.get(data, field) |> C4.Utils.maybe([]) |> List.flatten()
        value = C4.Value.parse_from_item(data, type, field, value)

        value =
          current_value
          |> Enum.filter(fn
            x when is_map(x) -> x.id != value
            x -> x != value
          end)

        C4.Value.insert(data, field, value, params["idx"])

      _ ->
        value = C4.Value.parse_from_item(data, type, field, value)
        C4.Value.insert(data, field, value, params["idx"])
    end
  end

  def update_field(data, %{"type" => "boolean", "field" => field} = params) do
    value = if params["value"] == "on", do: true, else: false
    value = C4.Value.parse_from_item(data, "boolean", field, value)
    C4.Value.insert(data, field, value, params["idx"])
  end

  def update_field(data, %{"type" => type, "field" => field, "value" => value} = params) do
    case type do
      "tags" ->
            current_value = C4.Value.get(data, field)
            new_value =
              C4.Value.parse_from_item(data, type, field, value)
            value = [new_value | current_value] |> Enum.uniq() |> Enum.reverse()
            C4.Value.insert(data, field, value, params["idx"])
      # "tags" ->
      #   case params["key"] do
      #     v when v in ["Enter", ","] ->
      #       current_value = C4.Value.get(data, field)

      #       new_value =
      #         C4.Value.parse_from_item(data, type, field, value |> String.replace(",", ""))

      #       value = [new_value | current_value] |> Enum.uniq() |> Enum.reverse()
      #       C4.Value.insert(data, field, value, params["idx"])

      #     _ ->
      #       data
      #   end

      "select_multiple" ->
        if value !== "" do

          current_value = C4.Value.get(data, field)
          new_value = C4.Value.parse_from_item(data, type, field, value)
          value = [new_value | current_value] |> List.flatten() |> Enum.uniq() |> Enum.reverse()
          C4.Value.insert(data, field, value, params["idx"])
        else
          data
        end

      _ ->
        value = C4.Value.parse_from_item(data, type, field, value)
        C4.Value.insert(data, field, value, params["idx"])
    end
  end

  def add_one(data, %{"model" => model, "fields" => fields, "field" => field}) do
    model =
      struct(String.to_atom(model))
      |> Map.take(String.split(fields, ",") |> Enum.map(&String.to_atom/1))

    items = [{C4.Utils.unique(5), model} | C4.Value.get(data, field) || []]
    C4.Value.insert(data, field, items)
  end

  def remove_one(data, %{"idx" => idx_r, "field" => field}) do
    items =
      C4.Value.get(data, field)
      |> C4.Utils.maybe([])
      |> Enum.filter(fn {idx, _item} -> idx != idx_r end)

    C4.Value.insert(data, field, items)
  end
end
