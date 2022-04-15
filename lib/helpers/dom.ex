defmodule C4.Dom do
  def dom(_value, _assigns \\ %{})
  def dom([], _assigns), do: []
  def dom(value, _assigns) when is_bitstring(value), do: value

  def dom(value, _assigns) when is_atom(value) do
    to_string(value)
  end

  def dom([{key, _attrs_, _children_} = node | tail], assigns) when is_bitstring(key) do
    [dom(node, assigns) | dom(tail, assigns)]
  end

  def dom({node, _attrs_, _children_} = dom_, assigns) when is_atom(node) do
    parse_component(dom_, assigns) |> dom(assigns)
  end

  def dom({node, attrs_, value}, _assigns) when is_bitstring(node) and value in [nil, []] do
    "<#{node} #{attributes(attrs_)} />"
  end

  def dom({node, attrs_, text}, _assigns) when is_bitstring(node) and is_bitstring(text) do
    "<#{node} #{attributes(attrs_)} >#{text}</#{node}>"
  end

  def dom({node, attrs_, children_}, assigns) when is_bitstring(node) and is_list(children_) do
    "<#{node} #{attributes(attrs_)} >" <>
      Enum.map_join(children_, &dom(&1, assigns)) <> "</#{node}>"

    # {node, attributes(attrs_), dom(children_)}
  end

  def attributes(list) do
    Enum.map_join(list, " ", &"#{to_string(elem(&1, 0))}=#{parse_attribute(elem(&1, 1))}")
  end

  defp parse_attribute(attr) do
    cond do
      is_bitstring(attr) or is_atom(attr) -> "\'#{attr}\'"
      :else -> "{#{attr}}"
    end
  end

  defp parse_component({node, attrs_, children_}, assigns) do
    case node do
      :label ->
        dom_label(attrs_, children_, assigns)

      :input ->
        options = C4.Value.get(assigns, "types.#{attrs_[:field]}", %{})
        value = C4.Value.get(assigns, attrs_[:field], options[:default])
        type = options[:form] || options[:type_]

        if is_function(assigns[:form_parse], 6) do
          assigns[:form_parse].(assigns, type, options, attrs_, children_, value)
        else
          {"span", [], "don't have <b>form_parse</b> defined in assigns"}
        end

      atom ->
        "<.live_component #{attributes(attrs_)} module={#{atom}} id=\"#{C4.Utils.unique(10)}\" />"
    end
  end

  defp dom_label(attrs, children, assigns) do
    case children do
      [] ->
        options = C4.Value.get(assigns, "types.#{attrs[:field]}", %{})
        tip = "#{options[:tip]}" |> String.replace("\n", "") |> String.trim()
        {"label", ["data-html": tip, class: attrs[:class], style: attrs[:style]], options[:label]}

      chld ->
        {"label", [class: attrs[:class], style: attrs[:style]], chld}
    end
  end
end
