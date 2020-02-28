defmodule Automaton do
  @moduledoc """
    This is the primary user control interface to the Automata system. The
    configration parameters are used to inject the appropriate modules into the
    user-defined nodes based on their node_type and other options.

    Notes:
    Initialization and shutdown require extra care:
    on_init: receive extra parameters, fetch data from blackboard/utility,  make requests, etc..
    shutdown: free resources to not effect other actions

    Multi-Agent Systems
      Proactive & Reactive agents
      BDI architecture: Beliefs, Desires, Intentions
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

    # composite(control node) or action(execution node)? if its a
    # composite(control) node, the Automaton.CompositeSupervisor supervises this
    # control(root) node, which runs all user nodes(which are GenServer workers
    # that start and add children(composite or component) to a
    # CompositeSupervisor(for composite nodes) or run the GenServer(for action
    # nodes) as children of Automaton.CompositeSupervisor)
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

    # TODO: for the love of god, find the elixir way to do this..
    # if Enum.member?(c_types, nt) do
    #   IO.puts("LKJLKJLKJLJ")
    #   quote do: use(CompositeServer, user_opts: unquote(user_opts))
    # else
    #   if Enum.member?(cn_types, nt) do
    #     quote do: use(ComponentServer, user_opts: unquote(user_opts))
    #   else
    #     raise "UserInitError"
    #   end
    # end

    control =
      quote do
        # should tick each subtree at a frequency corresponding to subtrees tick_freq
        # each subtree of the user-defined composite node will be ticked
        # every update (at rate tick_freq) as we update the tree until we find
        # the leaf node that is currently running (will be an action).
        def tick(state) do
          new_state = if state.status != :bh_running, do: on_init(state), else: state

          # IO.inspect([
          #   "[#{Process.info(self)[:registered_name]}][tick] updating node...",
          #   Process.info(self)[:registered_name]
          # ])

          status = update(new_state)

          if status != :bh_running do
            on_terminate(status)
          else
            schedule_next_tick(new_state.tick_freq)
          end

          IO.inspect(
            [
              DateTime.now!("Etc/UTC") |> DateTime.to_time(),
              "ticked",
              state.status,
              status
            ],
            label: Process.info(self)[:registered_name]
          )

          IO.puts("\n")
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
