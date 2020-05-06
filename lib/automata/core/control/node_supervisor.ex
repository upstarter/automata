defmodule Automaton.NodeSupervisor do
  use DynamicSupervisor

  def start_link([automaton_server, {_, _, _} = mfa, name]) do
    DynamicSupervisor.start_link(__MODULE__, [automaton_server, mfa, name],
      name: :"#{name}NodeSupervisor"
    )
  end

  @spec init([]) :: no_return
  def init([automaton_server, {_m, _f, _a}, _name]) do
    Process.link(automaton_server)

    opts = [
      strategy: :one_for_one,
      max_restart: 5,
      max_time: 3600
    ]

    DynamicSupervisor.init(opts)
  end

  def child_spec([[_automaton_server, {_m, _f, _a}, name]] = args) do
    %{
      id: name <> "NodeSupervisor",
      start: {__MODULE__, :start_link, args},
      shutdown: 10_000,
      restart: :temporary,
      type: :supervisor
    }
  end
end
