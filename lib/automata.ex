defmodule Automata do
  @moduledoc """

  """

  @typedoc """
  All automata start with a %State{}.
  """
  @type state :: module()

  @typedoc "The error state returned by `Automata.WorldInfo` and `Automata.AutomatonInfo`"
  @type failed :: [{Exception.kind(), reason :: term, Exception.stacktrace()}]

  @typedoc "A map representing the results of running an agent"
  @type agent_result :: %{
          failures: non_neg_integer,
          total: non_neg_integer
        }

  defmodule AutomatonInfo do
    @moduledoc """
    A struct that keeps local information specific to the automaton for a world.
    It is received by formatters and contains the following fields:
      * `:name` - the automaton name
      * `:module` - the automaton module
      * `:state` - the automaton state
      * `:time` - the duration in microseconds of the automatons' init sequence
      * `:tags` - the automaton tags
      * `:logs` - the captured logs
    """
    defstruct [:name, :module, :state, time: 0, tags: %{}, logs: ""]

    @type t :: %__MODULE__{
            name: atom,
            module: module,
            state: Automaton.state(),
            time: non_neg_integer,
            tags: map,
            logs: String.t()
          }
  end

  defmodule WorldInfo do
    @moduledoc """
    A struct that keeps global information about all automata for the world.
    It is received by formatters and contains the following fields:
      * `:name`  - the world name
      * `:state` - the automata state (see `t:Automata.state/0`)
      * `:automata` - all automata in the world
    """
    defstruct [:name, :state, automata: []]

    @type t :: %__MODULE__{name: module, state: Automata.state(), automata: [Automata.t()]}
  end

  defmodule TimeoutError do
    defexception [:timeout, :type]

    @impl true
    def message(%{timeout: timeout, type: type}) do
      """
      #{type} timed out after #{timeout}ms. You can change the timeout:
        1. per automaton by setting "timeout: x" on automaton state (accepts :infinity)
        2. per automata by setting "@moduletag timeout: x" (accepts :infinity)
        3. globally ubiquitous timeout via "Automata.start(timeout: x)" configuration
      where "x" is the timeout given as integer in milliseconds (defaults to 60_000).
      """
    end
  end

  defmodule MultiError do
    @moduledoc """
    Raised to signal multiple automata errors which happened in a world.
    """

    defexception errors: []

    @impl true
    def message(%{errors: errors}) do
      "got the following errors:\n\n" <>
        Enum.map_join(errors, "\n\n", fn {kind, error, stack} ->
          Exception.format_banner(kind, error, stack)
        end)
    end
  end

  use Application

  # TODO: recursively autoload all the user-defined worlds from the worlds/ directory tree
  # to build the config() data structure ie. config for each agent from world config
  # which defines which automata which are operating in that world.
  @doc false
  def start(_type, []) do
    children = [
      # Automata.AutomataServer,
      # Automata.CaptureServer,
      # Automata.OnExitHandler
    ]

    {:ok, _pid} = run()

    opts = [strategy: :one_for_one]

    Supervisor.start_link(children, opts)
  end

  # @doc """
  # Starts Automata and automatically runs the world(s) right before the VM
  # terminates.
  # It accepts a set of `options` to configure `Automata`
  # (the same ones accepted by `configure/1`).
  # If you want to run worlds manually, you can set the `:autorun` option
  # to `false` and use run/0 to run worlds.
  # """
  @spec start(Keyword.t()) :: :ok
  def start(options \\ []) do
    {:ok, _} = Application.ensure_all_started(:automata)

    configure(options)

    if Application.fetch_env!(:automata, :autorun) do
      Application.put_env(:automata, :autorun, false)

      System.at_exit(fn
        0 ->
          options = persist_defaults(configuration())
          :ok = Automata.Operator.run(options)

        _ ->
          :ok
      end)
    else
      :ok
    end
  end

  @doc """
  Configures Automata.
  ## Options
  Automata supports the following options:
    * `:trace` - sets Automata into trace mode, this allows agents to print info
  on an episode(s) while running.
  Any arbitrary configuration can also be passed to `configure/1` or `start/1`,
  and these options can then be used in places such as the builtin automaton types
  configurations. These other options will be ignored by the Automata core itself.
  """
  @spec configure(Keyword.t()) :: :ok
  def configure(options) do
    Enum.each(options, fn {k, v} ->
      Application.put_env(:automata, k, v)
    end)
  end

  @doc """
  Returns Automata configuration.
  """
  @spec configuration() :: Keyword.t()
  def configuration do
    Application.get_all_env(:automata)
  end

  @doc """
  Runs the world. It is invoked automatically
  if Automata is started via `start/1`.
  """
  @spec run() :: agent_result()
  def run do
    options = persist_defaults(configuration())
    {:ok, _pid} = Automata.Operator.run(options)
  end

  @doc """
  Begins update of Behavior Tree. More agent types to come.
  TODO: remove test env, get from config
  """
  @spec begin() :: agent_result()
  def begin do
    if Mix.env() == :test do
      send(TestMockSeq1Server, :update)
    else
      send(MockSeq1Server, :update)
    end
  end

  # Persists default values in application
  # environment before the automata start.
  defp persist_defaults(config) do
    config |> Keyword.take([:seed, :trace]) |> configure()
    config
  end

  def status(automaton_name) do
    Automaton.AgentServer.status(automaton_name)
  end
end
