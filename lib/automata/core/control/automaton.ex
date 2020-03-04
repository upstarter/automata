defmodule Automaton do
  @moduledoc """
    This is the primary user control interface to the Automata system. The
    configration parameters are used to inject the appropriate modules into the
    user-defined nodes based on their node_type and other options.

    Notes:
    Initialization and shutdown require extra care:
    on_init: receive extra parameters, fetch data from blackboard/utility,  make requests, etc..
    shutdown: free resources to not effect other actions

    TODO: store any currently processing nodes so they can be ticked directly
    within the behaviour tree engine rather than per tick traversal of the entire
    tree. Zipper Tree?
  """
  alias Automaton.Behavior
  alias Automaton.CompositeServer
  alias Automaton.ComponentServer

  defmacro __using__(user_opts) do
    prepend =
      quote do
        # all nodes are Behavior's
        use Behavior, user_opts: unquote(user_opts)
      end

    c_types = CompositeServer.types()
    cn_types = ComponentServer.types()
    allowed_node_types = c_types ++ cn_types
    node_type = user_opts[:node_type]
    unless Enum.member?(allowed_node_types, node_type), do: raise("NodeTypeError")

    node_type =
      cond do
        Enum.member?(c_types, node_type) ->
          quote do: use(CompositeServer, user_opts: unquote(user_opts))

        Enum.member?(cn_types, node_type) ->
          quote do: use(ComponentServer, user_opts: unquote(user_opts))
      end

    control =
      quote do
        def tick(state) do
          new_state = if state.status != :bh_running, do: on_init(state), else: state

          # IO.inspect([
          #   "[#{Process.info(self)[:registered_name]}][tick] updating node...",
          #   Process.info(self)[:registered_name]
          # ])

          status = update(new_state)

          if status != :bh_running do
            on_terminate(status)
            # else
            #   schedule_next_tick(new_state.tick_freq)
          end

          # IO.inspect(
          #   [
          #     DateTime.now!("Etc/UTC") |> DateTime.to_time(),
          #     "ticked",
          #     state.status,
          #     status
          #   ],
          #   label: Process.info(self)[:registered_name]
          # )

          # IO.puts("\n")
          [status, new_state]
        end

        def schedule_next_tick(ms_delay) do
          # IO.inspect(
          #   log: "[#{Process.info(self)[:registered_name]}] SCHEDULING NEXT TICK",
          #   self: Process.info(self())[:registered_name]
          # )

          Process.send_after(self(), :scheduled_tick, ms_delay)
        end

        @impl GenServer
        def handle_call(:tick, _from, state) do
          [status, new_state] = tick(state)
          {:reply, status, new_state}
        end

        @impl GenServer
        def handle_info(:scheduled_tick, state) do
          [status, new_state] = tick(state)
          {:noreply, new_state}
        end
      end

    [prepend, node_type, control]
  end
end
