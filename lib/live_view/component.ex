defmodule C4.Component do
  @moduledoc false
  use Phoenix.LiveComponent
  import C4.Helpers.Web, only: [clean_assigns: 1]
  defmacro __using__(_opts) do
    quote do
      use Phoenix.LiveComponent
      @before_compile unquote(__MODULE__)
      import C4.Component
      import C4.Helpers.Web, only: [clean_assigns: 1]
      alias C4.Dom, as: H

      Module.register_attribute(__MODULE__, :fields, accumulate: true)
      Module.register_attribute(__MODULE__, :events, accumulate: true)
      Module.register_attribute(__MODULE__, :effects, accumulate: true)
      Module.register_attribute(__MODULE__, :javascripts, accumulate: true)
      Module.register_attribute(__MODULE__, :commands, accumulate: true)
      Module.register_attribute(__MODULE__, :schema, [])

      def call_event(socket, event) do
        send(self(), event)
      end
    end
  end

  defmacro __before_compile__(env) do
    [init_component(env)]
  end

  defp init_component(_env) do
    prelude =
      quote do
        @doc false
        def mount(socket) do
          {:ok,
           socket
           |> assign(:__fields__, @fields)
           |> assign(:self_module, __MODULE__)
           |> assign(:run_once, false)
           |> apply_default_fields()}
        end
      end

    postlude =
      quote do
        @doc false
        def handle_event(event, params, socket) do
          func = Keyword.get(@events, String.to_atom(event))

          {assigns, socket} =
            if is_function(func, 2) do
              case func.(socket.assigns, params) do
                {data, command} ->
                  {data, socket |> apply_command(command, @commands, @javascripts)}

                data when is_map(data) ->
                  {data, socket}
              end
            else
              {socket.assigns, socket}
            end

          assigns = assigns |> clean_assigns()
          {:noreply, assign(socket, assigns)}
        end
      end

    init =
      quote do
        def update(%{__port__: event, __payload__: payload} = params, socket) do
          func = Keyword.get(@events, event)

          {assigns, socket} =
            if is_function(func, 2) do
              func.(socket.assigns, payload)
              |> case do
                {data, command} ->
                  {data, socket |> apply_command(command, @commands, @javascripts)}

                data when is_map(data) ->
                  {data, socket}
              end
            else
              {socket.assigns, socket}
            end

          assigns = assigns |> clean_assigns()
          {:ok, socket |> assign(assigns)}
        end

        def update(%{__event__: event} = params, socket) do
          opts = params[:__opts__] || []
          func = Keyword.get(@events, event)

          {assigns, socket} =
            if is_function(func, 2) do
              func.(socket.assigns, params)
              |> case do
                {data, command} ->
                  {data, socket |> apply_command(command, @commands, @javascripts)}

                data when is_map(data) ->
                  {data, socket}
              end
            else
              {socket.assigns, socket}
            end

          if opts[:effect] == true && opts[:every] do
            send_update_after(
              self(),
              socket.assigns.self_module,
              [id: socket.assigns.id, __event__: event, __opts__: opts],
              opts[:every]
            )
          end

          assigns = assigns |> clean_assigns()
          {:ok, socket |> assign(assigns)}
        end

        def update(assigns, socket) do
          {:ok,
           socket
           |> assign(assigns)
           |> apply_effects(@effects)
           |> apply_fields()
           |> merge_differences(assigns)}
        end
      end

    quote do
      unquote(prelude)
      unquote(postlude)
      unquote(init)
    end
  end


  def render(assigns), do: ~H".."

  defmacro sigil_J({:<<>>, meta, [template]}, []) do
    ast = EEx.compile_string(template, line: meta[:line] + 1)

    quote line: meta[:line] do
      unquote(ast)
    end
  end

  def header() do
    """
    /*
    This file was generated automatically by the C4 compiler.
    */\
    """
  end

  def header_functions(prefix) do
    """
    \n
    const push = function(atom, module = "#{prefix}", id, payload) {
      liveSocket.getSocket().channels[0].push("port["+module+"]["+id+"]["+atom+"]", payload)
    }
    const push_self = function(atom, id, payload) {
      liveSocket.getSocket().channels[0].push("port[#{prefix}]["+id+"]["+atom+"]", payload)
    }
    \n
    """
  end

  defmacro script(name, do: content) do
    {name, args} =
      case name do
        {_name, _args} = n -> n
        name -> {name, []}
      end

    quote do
      name = unquote(name)
      cnt = unquote(content)
      prefix = String.split("#{__MODULE__}", ".") |> Enum.join("_")
      hash = "#{prefix}_#{name}"
      js_output_dir = Path.join([File.cwd!(), "assets/js/C4/"])
      File.mkdir_p!(js_output_dir)
      dest_file = Path.join([js_output_dir, "#{hash}.js"])
      index_file = Path.join([js_output_dir, "index.js"])

      content = [
        header(),
        header_functions(prefix),
        "export default function(e){\n const params = e.detail;\n",
        cnt,
        "}"
      ]

      content_index = [
        "import #{prefix}_#{name} from './#{hash}';",
        "window.addEventListener(`phx:#{hash}`, #{prefix}_#{name});"
      ]

      if !File.exists?(index_file), do: File.touch!(index_file)
      src = File.read!(index_file)

      c = content_index |> Enum.join()
      c = String.replace(src, c, "") |> String.replace("\n", "")
      File.write!(index_file, [c, content_index, "\n"] |> List.flatten())

      File.write!(dest_file, content)
      Module.put_attribute(__MODULE__, :javascripts, {name, "#{hash}", unquote(args)})
    end
  end

  defmacro event(mfld, do: funct) do
    quote do
      Module.put_attribute(__MODULE__, :events, {unquote(mfld), unquote(funct)})
    end
  end

  defmacro schema(schm) do
    quote do
      Module.put_attribute(__MODULE__, :schema, unquote(schm))
    end
  end

  defmacro view(do: block) do
    b = block
        |> Macro.prewalk(fn
          {:<<>>, x, args} -> {:<<>>, x, parse_heex(args)}
          c -> c
        end)
  
    quote do
      def render(var!(assigns)) do
        unquote(b)
      end
    end
  end

  defmacro dom(do: block) do
  b = block
      |> Macro.prewalk(fn
        {:<<>>, x, args} -> {:<<>>, x, parse_heex(args)}
        c -> c
      end)
    options = [
          engine: Phoenix.LiveView.HTMLEngine,
          file: __CALLER__.file,
          line: __CALLER__.line + 1,
          module: __CALLER__.module,
          indentation: 0
        ]
    #EEx.compile_string(expr, options)
    quote do
      def render(var!(assigns)) do
          unquote(block)
          |> C4.Dom.dom(var!(assigns))
          |> EEx.compile_string(unquote(options))
          |> Code.eval_quoted([assigns: var!(assigns)], __ENV__)
          |> elem(0)
          
      end
      # def render(var!(assigns)) do
      #   ~H"""
      #     <div>loading</div>
      #   """
      # end
      
    end
  end

  defmacro v(value, default \\ "") do
    #Macro.Env.has_var?(__CALLER__, {:assigns, nil})
    quote do
      C4.Value.get(var!(assigns), unquote(value), unquote(default))
    end
  end

  @doc """
    command :command, opts
    command {:command, args}, opts (when args is a list of atom)
  """
  defmacro command(cmd, opts \\ []) do
    quote do
      Module.put_attribute(__MODULE__, :commands, {unquote(cmd), unquote(opts)})
    end
  end

  @doc """
    effect :event, opts
  """
  defmacro effect(event, opts \\ []) do
    quote do
      Module.put_attribute(__MODULE__, :effects, {unquote(event), unquote(opts)})
    end
  end

  @doc """
    field :field, :type, 
          default: "value" || function, 
          format: function
  """
  defmacro field(fld, type, opts) do
    quote do
      Module.put_attribute(__MODULE__, :fields, {unquote(fld), unquote(type), unquote(opts)})
    end
  end

  def apply_default_fields(socket) do
    fields = socket.assigns[:__fields__]
    apply_default_fields(socket, fields)
  end

  def apply_default_fields(socket, []), do: socket

  def apply_default_fields(socket, [{fld, type, opts} | tail]) do
    socket
    |> apply_fields_private({fld, type, opts})
    |> apply_default_fields(tail)
  end

  def apply_fields(socket) do
    fields = socket.assigns[:__fields__]
    apply_fields(socket, fields)
  end

  def apply_fields(socket, []), do: socket

  def apply_fields(socket, [{fld, type, opts} | tail]) do
    apply_fields_private(socket, {fld, type, opts})
    |> apply_default_fields(tail)
  end

  def apply_fields_private(socket, {fld, _type, opts}) do
    default = opts[:default]

    value =
      cond do
        is_nil(default) -> opts[:value]
        :else -> default
      end

    format = opts[:format]
    # GET VALUE
    value =
      cond do
        is_function(value, 0) -> value.()
        is_function(value, 1) -> value.(socket)
        is_function(value) -> value
        :else -> value
      end

    # FORMAT VALUE
    value = if is_function(format), do: format.(value), else: value

    socket
    |> assign(fld, value)
  end

  def apply_fields_private(socket, _), do: socket

  def merge_differences(socket, assigns) do
    assigns =
      Map.to_list(assigns)
      |> Enum.map(fn {key, value} -> {key, :field, value: value} end)

    apply_default_fields(socket, assigns)
  end

  def apply_command(_socket, _list, _commands, _javascripts \\ [])
  def apply_command(socket, [], _commands, _javascripts), do: socket

  def apply_command(socket, [command | list], commands, _javascripts) do
    socket
    |> apply_command(command, commands)
    |> apply_command(list, commands)
  end

  def apply_command(socket, {:javascript, atom}, _commands, javascripts) do
    {key, args} =
      case atom do
        {key, args} -> {key, args}
        key -> {key, []}
      end

    Enum.find(javascripts, fn
      {c, _, _args} -> c == key
      _ -> false
    end)
    |> case do
      nil ->
        socket

      {_, name, args1} ->
        args = Enum.zip(args1, args) |> Map.new()
        push_event(socket, name, args)
    end

    # socket
  end

  def apply_command(socket, {command, args}, commands, _javascripts) do
    Enum.find(commands, fn
      {{c, _args}, _} -> c == command
      _ -> false
    end)
    |> case do
      {{_command, args_keys}, [do: function]} ->
        function.(socket, Enum.zip(args_keys, args) |> Map.new())

      nil ->
        socket
    end
  end

  def apply_command(socket, command, commands, _javascripts) when is_atom(command) do
    Enum.find(commands, fn
      {c, _} -> c == command
      _ -> false
    end)
    |> case do
      {_command, [do: function]} ->
        function.(socket)

      nil ->
        socket
    end
  end

  def apply_effects(socket, []), do: socket

  def apply_effects(socket, [sub | tail]) do
    run_effect(socket, sub)
    apply_effects(socket, tail)
  end

  def run_effect(%{assigns: %{run_once: false}} = socket, {event, opts}) do
    module = socket.assigns.self_module
    id = socket.assigns.id
    # params = if is_function(func,0), do: func.()
    case opts[:every] do
      nil ->
        send_update(self(), module, id: id, __event__: event)

      sec ->
        opts = opts ++ [effect: true]
        send_update_after(self(), module, [id: id, __event__: event, __opts__: opts], sec)
    end
  end

  def run_effect(socket, _), do: socket

  def get_opts(fields, field, key_opt, default \\ nil) do
    Enum.find(fields, fn {key, _, _} -> key == field end)
    |> case do
      nil -> "[no-schema-field]"
      {_key, _type, opts} -> opts[key_opt] || default
    end
    |> maybe_parse_function()
  end

  def maybe_parse_function({module, function, args}) do
    apply(:"#{module}.Api", function, args)
  end

  def maybe_parse_function(result), do: result

  def parse_heex([content]) do
    # replace $() to get_opts() function
    [String.replace(content, "$(", "get_opts(@__fields__, ")]
  end
end
