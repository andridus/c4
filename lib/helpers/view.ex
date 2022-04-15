defmodule C4.Helpers.View do
  @moduledoc false
  use C4.Component

  def render(assigns), do: ~H".."

  def model(assigns, field, object, opts) do
    idx = opts[:idx]
    fields_type = "#{object}_fields"
    path = "#{object}.#{field}"
    type = opts[:type] || get_type(assigns, fields_type, field)

    root =
      if is_nil(idx) do
        assigns
      else
        C4.Value.get(assigns, object)
        |> C4.Helpers.maybe([])
        |> Enum.find(fn {x, _} -> x == idx end)
        |> case do
          nil -> nil
          {_, d} -> Map.new([{object, d}])
        end
      end

    value =
      C4.Value.get(root, path)
      |> case do
        %Ecto.Association.NotLoaded{} -> default_from_type(type)
        v -> v
      end

    do_func = opts[:do]

    if !is_nil(do_func) && is_function(do_func, 2) do
      do_func.(
        value,
        get_type_(assigns, fields_type, field) |> Map.new()
      )
    else
      "-"
    end
  end

  def render_input(assigns, field, object, opts) do
    class = opts[:class]
    style = opts[:style]
    atom = opts[:atom]
    disabled = opts[:disabled]
    idx = opts[:idx]
    label = opts[:label]
    label_hide = opts[:label_hide]
    fields_type = "#{object}_fields"
    path = "#{object}.#{field}"
    type = opts[:type] || get_type(assigns, fields_type, field)

    root =
      if is_nil(idx) do
        assigns
      else
        C4.Value.get(assigns, object)
        |> C4.Helpers.maybe([])
        |> Enum.find(fn {x, _} -> x == idx end)
        |> case do
          nil -> nil
          {_, d} -> Map.new([{object, d}])
        end
      end

    current_value =
      C4.Value.get(root, path)
      |> case do
        %Ecto.Association.NotLoaded{} -> default_from_type(type)
        v -> v
      end

    input =
      case type do
        :buttons ->
          ~H"""
            <div>
              <%= for {key, value} <-  get(assigns, fields_type, field, :options) do %>
                <div
                type="checkbox" 
                checked={current_value}
                disabled={disabled}
                phx-click={atom}
                phx-value-type={type}
                phx-value-field={path} 
                phx-value-scope={object} 
                phx-value-idx={idx} 
                phx-target={@myself} 
                phx-value-value={key} 
                class={" button #{if current_value == key, do: "primary"}"}><%= value %></div>
              <% end %>
            </div>
          """

        :boolean ->
          ~H"""
            <div>
              <input
                type="checkbox" 
                checked={current_value}
                disabled={disabled}
                phx-click={atom}
                phx-value-type={type}
                phx-value-field={path} 
                phx-value-scope={object} 
                phx-value-idx={idx} 
                phx-target={@myself} 
                phx-value-value={if !current_value , do: "true", else: "false"} 
                class={" toggle toggle-lg #{if current_value, do: "toggle-primary"}"} />
            </div>
          """

        :select ->
          ~H"""
            <select id={C4.Helpers.unique(5)} class="px-2 py-1 border z-50 cursor-pointer border-0 flex-1 group relative"
              disabled={disabled}
              phx-click={atom}
              phx-keyup={atom}
              phx-value-field={path}
              phx-value-type={type}
              phx-value-scope={object} 
              phx-value-idx={idx} 
              phx-target={@myself} >
                <option value="" selected={is_nil(current_value)} disabled> Selecione </option>
                <%= for {key, value} <-  get(assigns, fields_type, field, :options) do %>
                  <option value={key} selected={current_value == "#{key}"}><%= value %> </option>
                <% end %>
            </select>
          """

        :select_multiple ->
          ~H"""
            <div class="border min-w-full flex flex-wrap items-center">
            <%= current_value |> Enum.with_index() |> Enum.map(fn {t, _idxl} ->%>
              <div id={C4.Helpers.unique(10)} class="flex-none rounded-xs">
                <div class="bg-gray-200  m-1 ">
                  <%= if disabled do %>
                    <span class="mx-2 inline-block pointer-events-none"> <%= t %></span>
                  <% else %>
                    <span class="ml-2 inline-block"> <%= parse_value(assigns, fields_type, field, t) %></span>
                    <i 
                      class="mx-2 fas fa-times cursor-pointer hover:text-red-500"
                      phx-target={@myself}
                      phx-click={atom}
                      phx-value-type={type}
                      phx-value-idx={idx}
                      phx-value-scope={object}
                      phx-value-field={path}
                      phx-value-remove={true}
                      phx-value-value={t}
                    ></i>
                  <% end %>
                </div>
              </div>
            <% end)%>
            <%= unless disabled do %>
                <select id={C4.Helpers.unique(5)} class="px-2 py-1 border z-50 cursor-pointer border-0 flex-1 group relative"
                  disabled={disabled}
                  phx-click={atom}
                  phx-keyup={atom}
                  phx-value-field={path}
                  phx-value-type={type}
                  phx-value-scope={object} 
                  phx-value-idx={idx} 
                  phx-target={@myself} >
                    <option value="" selected={is_nil(current_value) || current_value == [] } disabled> Selecione </option>
                    <%= for {key, value} <-  get(assigns, fields_type, field, :options) do %>
                      <option value={key} ><%= value %> </option>
                    <% end %>
                </select>
            <% end %>
          </div>
          """

        {:array, :map} ->
          ~H"""
           map
          """

        {:array, :string} ->
          ~H"""
           string
          """

        :string ->
          ~H"""
           <input
            disabled={disabled}
            class="px-2 py-1 border border-1 flex-1" 
            value={current_value} autocomplete="off" autofill="off" 
            phx-keyup={atom} 
            phx-value-field={path} 
            phx-value-type={type}
            phx-value-scope={object}
            phx-value-idx={idx}   
            phx-debounce="500" 
            phx-target={@myself} 
            />
          """

        :price ->
          ~H"""
           <input
            disabled={disabled}
            class="px-2 py-1 border border-1 flex-1" 
            value={current_value} autocomplete="off" autofill="off" 
            phx-keyup={atom} 
            phx-value-field={path} 
            phx-value-type={type}
            phx-value-scope={object}
            phx-value-idx={idx}   
            phx-debounce="500" 
            phx-target={@myself} 
            />
          """

        v when v in [:number, :integer] ->
          ~H"""
           <input
            type="number"
            disabled={disabled}
            class="px-2 py-1 border border-1 flex-1" 
            value={current_value} 
            autocomplete="off" autofill="off" 
            phx-keyup={atom} 
            phx-value-field={path} 
            phx-value-type={type}
            phx-value-scope={object}
            phx-value-idx={idx}   
            phx-debounce="500" 
            phx-target={@myself} 
            />
          """

        :email ->
          ~H"""
           <input 
            type="email"
            class="px-2 py-1 border border-1 flex-1" 
            value={current_value} autocomplete="off" autofill="off" 
            disabled={disabled}
            phx-keyup={atom} 
            phx-value-field={path} 
            phx-value-type={type}
            phx-value-scope={object}
            phx-value-idx={idx}   
            phx-debounce="500" 
            phx-target={@myself} 
            />
          """

        :date ->
          ~H"""
           <input 
            type="date"
            class="px-2 py-1 border border-1 flex-1" 
            value={current_value} autocomplete="off" autofill="off" 
            disabled={disabled}
            phx-keyup={atom} 
            phx-value-field={path} 
            phx-value-type={type}
            phx-value-scope={object}
            phx-value-idx={idx}   
            phx-debounce="500" 
            phx-target={@myself} 
            />
          """

        :textarea ->
          ~H"""
           <textarea
            class="px-2 py-1 border border-1 flex-1" 
            autocomplete="off" autofill="off" 
            disabled={disabled}
            phx-keyup={atom} 
            phx-value-field={path} 
            phx-value-type={type}
            phx-value-scope={object}
            phx-value-idx={idx}   
            phx-debounce="500" 
            phx-target={@myself}
            style={style}
            ><%=current_value%></textarea>
          """

        :images ->
          ~H"""
           <div class="border min-w-full flex flex-wrap items-center">
            <%= current_value |> Enum.with_index() |> Enum.map(fn {t, _idx} ->%>
              <img id={C4.Helpers.unique(10)} src={t} class="border flex-none rounded-xs w-32 h-32" />
            <% end)%>
          </div>
          """

        :tags ->
          ~H"""
            <div class="border min-w-full flex flex-wrap items-center">
            <%= current_value |> Enum.with_index() |> Enum.map(fn {t, idx} ->%>
              <div id={C4.Helpers.unique(10)} class="flex-none rounded-xs">
                <div class="bg-gray-200  m-1 ">
                  <%= if disabled do %>
                    <span class="mx-2 inline-block pointer-events-none"> <%= t %></span>
                  <% else %>
                    <span class="ml-2 inline-block"> <%= t %></span>
                    <i 
                      class="mx-2 fas fa-times cursor-pointer hover:text-red-500"
                      phx-target={@myself}
                      phx-click={atom}
                      phx-value-type={type}
                      phx-value-idx={idx}
                      phx-value-scope={object}
                      phx-value-field={path}
                      phx-value-remove={true}
                      phx-value-value={t}
                    ></i>
                  <% end %>
                </div>
              </div>
            <% end)%>
            <%= unless disabled do %>
              <input
                class="px-2 py-1 border border-1 flex-1" 
                autocomplete="off" autofill="off" 
                phx-keyup={atom} 
                phx-value-field={path} 
                phx-value-type={type}
                phx-value-scope={object}
                phx-value-idx={idx}   
                phx-target={@myself} 
              />
            <% end %>
          </div>
          """
      end

    ~H"""
      <div class={"p-2 py-1 flex flex-col #{class} "}>
        <%= unless label_hide, do: (label && render_label(label) ) ||render_label(assigns, fields_type, field) %>
        <%= input %>
        <div class="text-red-500 text-sm"> <%= C4.Value.get(assigns, "errors.#{path}") %></div>

      </div>
    """
  end

  def render_label(assigns, fields_type, field) do
    ~H"""
      <div class="flex items-center">
        <label class="py-2 font-bold text-xs"> <%= get(assigns, fields_type, field, :label) %>  </label>
        <.live_component id={C4.Helpers.unique(15)} module={C4.Components.Tooltip} content={get(assigns, fields_type, field, :tip)} style="z-index: 200"/>
      </div>
    """
  end

  def render_label(label) do
    assigns = %{}

    ~H"""
      <div class="flex items-center">
        <label class="py-2 font-bold text-xs"> <%= label %>  </label>
      </div>
    """
  end

  def render_button(assigns, field, opts) do
    icon = opts[:icon] || "fa-plus"
    atom = opts[:atom]
    idx = opts[:idx]
    label = opts[:label]
    class = opts[:class] || ""

    fields = opts[:fields]
    model = opts[:model]
    color = opts[:color] || "gray"

    color_class =
      "bg-#{color}-500 hover:border-#{color}-800 hover:bg-#{color}-700 text-white border-#{color}-500"

    ~H"""
      <div class={"flex justify-center items-center mb-2 px-4 p-2 border-2 rounded cursor-pointer transition transform duration-100 ease-linear #{color_class} #{class}"}
        phx-click={atom}
        phx-value-idx={idx}
        phx-value-field={field}
        phx-value-model={model} 
        phx-value-fields={fields} 
        phx-target={@myself} 
        > <i class={"fas #{icon}"}></i> <%= if label, do: Phoenix.HTML.raw "<div class='ml-2'>#{label}</div>" %></div>
    """
  end

  def render_add_button(assigns, atom, opts) do
    label = opts[:label] || "Adicionar"
    icon = opts[:icon] || "fa-plus"

    ~H"""
      <div phx-click={atom} phx-target={@myself} class="button py-2 text-xs">
        <i class={"fas #{icon}"}></i> <%= label %> 
      </div>
    """
  end

  def render_list_button(assigns, idx, atom, opts) do
    icon = opts[:icon] || "fa-plus"

    ~H"""
      <div class="btn btn-sm  mb-2 px-4 p-2 border-2 border-red-500 rounded cursor-pointer transition transform duration-100 ease-linear bg-red-500  hover:border-red-800 hover:bg-red-700 text-white"
        phx-click={atom}
        phx-value-idx={idx}
        phx-target={@myself} 
        > <i class={"fas #{icon}"}></i></div>
    """
  end

  def get(assigns, object, field, opt) do
    object = maybe_real_object(object)
    fields = C4.Value.get(assigns, object)

    Enum.find(fields, fn {key, _, _} -> key == field end)
    |> case do
      nil ->
        nil

      {_, _, opts} ->
        Keyword.get(opts, opt)
    end
    |> maybe_parse_function()
  end

  def get_type(assigns, object, field) do
    object = maybe_real_object(object)
    fields = C4.Value.get(assigns, object)

    Enum.find(fields, fn {key, _, _} -> key == field end)
    |> case do
      nil ->
        nil

      {_, type, opts} ->
        opts[:form] || type
    end
  end

  def get_type_(assigns, object, field) do
    object = maybe_real_object(object)
    fields = C4.Value.get(assigns, object)

    Enum.find(fields, fn {key, _, _} -> key == field end)
    |> case do
      nil -> nil
      {_, _type, opts} -> opts
    end
  end

  def maybe_real_object(object) do
    String.split("#{object}", ".")
    |> Enum.reverse()
    |> List.first()
  end

  def get_value(assigns, object, field, item) do
    fields = C4.Value.get(assigns, object)

    Enum.find(fields, fn {key, _, _} -> key == field end)
    |> case do
      nil ->
        nil

      {_, _, opts} ->
        Keyword.get(opts, :options)
    end
    |> maybe_parse_function()
    |> case do
      nil ->
        C4.Value.get(item, field)

      array ->
        v = C4.Value.get(item, field)

        Enum.reduce(array, v, fn
          {^v, val}, _acc -> val
          _, acc -> acc
        end)
    end
  end

  def parse_value(assigns, object, field, value) do
    fields = C4.Value.get(assigns, object)

    Enum.find(fields, fn {key, _, _} -> key == field end)
    |> case do
      nil ->
        nil

      {_, _, opts} ->
        Keyword.get(opts, :options)
    end
    |> maybe_parse_function()
    |> case do
      nil ->
        value

      array ->
        Enum.reduce(array, value, fn
          {^value, val}, _acc ->
            val

          {x, val}, acc ->
            cond do
              is_map(acc) && x == acc.id -> val
              :else -> acc
            end

          _, acc ->
            acc
        end)
    end
  end

  def default_from_type(type) do
    case type do
      :boolean -> false
      :select -> ""
      :select_multiple -> []
      {:array, :map} -> []
      :string -> ""
      :price -> ""
      :number -> 0
      :email -> ""
      :textarea -> ""
      :images -> []
      :tags -> []
    end
  end
end
