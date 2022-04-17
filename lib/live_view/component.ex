defmodule C4.Component do
  @moduledoc false
  use Phoenix.LiveComponent
  import C4.Helpers.Web, only: [clean_assigns: 1]

  defmacro __using__(_opts) do
    quote do
      use Phoenix.LiveComponent
      @before_compile unquote(__MODULE__)
      import C4.View
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
           |> C4.View.apply_default_fields()}
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
                  {data, socket |> C4.View.apply_command(command, @commands, @javascripts)}

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
                  {data, socket |> C4.View.apply_command(command, @commands, @javascripts)}

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
                  {data, socket |> C4.View.apply_command(command, @commands, @javascripts)}

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
           |> C4.View.apply_effects(@effects)
           |> C4.View.apply_fields()
           |> C4.View.merge_differences(assigns)}
        end
      end

    quote do
      unquote(prelude)
      unquote(postlude)
      unquote(init)
    end
  end

  defmacro dom(do: block) do
    b =
      block
      |> Macro.prewalk(fn
        {:<<>>, x, args} -> {:<<>>, x, C4.View.parse_heex(args)}
        c -> c
      end)

    options = [
      engine: Phoenix.LiveView.HTMLEngine,
      file: __CALLER__.file,
      line: __CALLER__.line + 1,
      module: __CALLER__.module,
      indentation: 0
    ]

    # EEx.compile_string(expr, options)
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
end
