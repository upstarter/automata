defmodule Automata.OnExitHandler do
  @moduledoc false

  @name __MODULE__
  @ets_opts [:public, :named_table, read_concurrency: true, write_concurrency: true]

  # ETS column numbers
  @supervisor 2
  @on_exit 3

  use Agent

  @spec start_link(keyword()) :: {:ok, pid}
  def start_link(_opts) do
    Agent.start_link(fn -> :ets.new(@name, @ets_opts) end, name: @name)
  end

  @spec register(pid) :: :ok
  def register(pid) when is_pid(pid) do
    :ets.insert(@name, {pid, nil, []})
    :ok
  end

  @spec add(pid, term, (() -> term)) :: :ok | :error
  def add(pid, name_or_ref, callback) when is_pid(pid) and is_function(callback, 0) do
    try do
      :ets.lookup_element(@name, pid, @on_exit)
    rescue
      _ -> :error
    else
      entries ->
        entries = List.keystore(entries, name_or_ref, 0, {name_or_ref, callback})
        true = :ets.update_element(@name, pid, {@on_exit, entries})
        :ok
    end
  end

  @spec get_supervisor(pid) :: {:ok, pid | nil} | :error
  def get_supervisor(pid) when is_pid(pid) do
    try do
      {:ok, :ets.lookup_element(@name, pid, @supervisor)}
    rescue
      _ -> :error
    end
  end

  @spec put_supervisor(pid, pid) :: :ok | :error
  def put_supervisor(pid, sup) when is_pid(pid) and is_pid(sup) do
    case :ets.update_element(@name, pid, {@supervisor, sup}) do
      true -> :ok
      false -> :error
    end
  end

  @spec run(pid, timeout) :: :ok | {Exception.kind(), term, Exception.stacktrace()}
  def run(pid, timeout) when is_pid(pid) do
    [{^pid, sup, callbacks}] = :ets.take(@name, pid)
    error = terminate_supervisor(sup, timeout)
    exec_on_exit_callbacks(Enum.reverse(callbacks), timeout, error)
  end

  defp terminate_supervisor(nil, _timeout), do: nil

  defp terminate_supervisor(sup, timeout) do
    ref = Process.monitor(sup)

    receive do
      {:DOWN, ^ref, _, _, _} -> nil
    after
      timeout ->
        {:error, Automata.TimeoutError.exception(timeout: timeout, type: "supervisor shutdown"),
         []}
    end
  end

  defp exec_on_exit_callbacks(callbacks, timeout, error) do
    {operator_pid, operator_monitor, error} =
      Enum.reduce(callbacks, {nil, nil, error}, &exec_on_exit_callback(&1, timeout, &2))

    if is_pid(operator_pid) and Process.alive?(operator_pid) do
      Process.exit(operator_pid, :shutdown)

      receive do
        {:DOWN, ^operator_monitor, :process, ^operator_pid, _error} -> :ok
      end
    end

    error || :ok
  end

  defp exec_on_exit_callback({_name_or_ref, callback}, timeout, operator) do
    {operator_pid, operator_monitor, error} = operator

    {operator_pid, operator_monitor} =
      ensure_alive_callback_operator(operator_pid, operator_monitor)

    send(operator_pid, {:run, self(), callback})
    receive_operator_reply(operator_pid, operator_monitor, error, timeout)
  end

  defp receive_operator_reply(operator_pid, operator_monitor, error, timeout) do
    receive do
      {^operator_pid, reason} ->
        {operator_pid, operator_monitor, error || reason}

      {:DOWN, ^operator_monitor, :process, ^operator_pid, reason} ->
        {nil, nil, error || {{:EXIT, operator_pid}, reason, []}}
    after
      timeout ->
        case Process.info(operator_pid, :current_stacktrace) do
          {:current_stacktrace, stacktrace} ->
            Process.exit(operator_pid, :kill)

            receive do
              {:DOWN, ^operator_monitor, :process, ^operator_pid, _} -> :ok
            end

            exception =
              Automata.TimeoutError.exception(timeout: timeout, type: "on_exit callback")

            {nil, nil, error || {:error, exception, stacktrace}}

          nil ->
            receive_operator_reply(operator_pid, operator_monitor, error, timeout)
        end
    end
  end

  ## Operator

  @doc false
  def on_exit_operator_loop do
    receive do
      {:run, from, fun} ->
        send(from, {self(), exec_callback(fun)})
        on_exit_operator_loop()
    end
  end

  defp ensure_alive_callback_operator(nil, nil) do
    spawn_monitor(__MODULE__, :on_exit_operator_loop, [])
  end

  defp ensure_alive_callback_operator(operator_pid, operator_monitor) do
    {operator_pid, operator_monitor}
  end

  defp exec_callback(callback) do
    callback.()
    nil
  catch
    kind, error ->
      {kind, error, __STACKTRACE__}
  end
end
