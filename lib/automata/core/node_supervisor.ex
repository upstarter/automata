defmodule Automata.NodeSupervisor do
  use DynamicSupervisor

  def start_link([automaton_server, {_, _, _} = mfa, name]) do
    DynamicSupervisor.start_link(__MODULE__, [automaton_server, mfa, name],
      name: :"#{name}NodeSupervisor"
    )
  end

  def init([automaton_server, {m, _f, a}, name]) do
    Process.link(automaton_server)

    opts = [
      strategy: :one_for_one,
      max_restart: 5,
      max_time: 3600
    ]

    DynamicSupervisor.init(opts)
  end

  def child_spec([[automaton_server, {m, _f, a}, name]] = args) do
    %{
      id: name <> "NodeSupervisor",
      start: {__MODULE__, :start_link, args},
      shutdown: 10000,
      restart: :temporary,
      type: :supervisor
    }
  end
end
