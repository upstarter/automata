defmodule Automaton.Types.NE.ExoSelf do
  alias Automaton.Types.NE.Sensor
  alias Automaton.Types.NE.Actuator
  alias Automaton.Types.NE.Cortex
  alias Automaton.Types.NE.Neuron
  require Logger

  @doc ~S"""
  The map/1 function maps the tuple encoded genotype into a process based
  phenotype. The map function expects for the cortex record to be the leading tuple
  in the tuple list it reads from the file_name. We create an ets table to map
  Ids to PIds and back again. Since the Cortex element contains all the Sensor
  Actuator, and Neuron Ids, we are able to spawn each neuron using its own gen
  function, and in the process construct a map from Ids to PIds. We then use
  link_cerebral_units to link all non Cortex elements to each other by sending
  each spawned pro- cess the information contained in its record, but with Ids
  converted to Pids where appropriate. Finally, we provide the Cortex process
  with all the PIds in the NN system by executing the link_cortex/2 function.
  Once the NN is up and running, exoself starts its wait until the NN has
  finished its job and is ready to backup. When the cortex initiates the backup
  process it sends exoself the updated Input_p_id_ps from its neurons. ExoSelf
  uses the update_genotype/3 function to update the old genotype with new
  weights, and then stores the updated version back to its file.
  """
  def map() do
    map(:ffnn)
  end

  def map(file_name) do
    {:ok, genotype} = :file.consult(file_name)
    task = Task.async(fn -> map(file_name, genotype) end)
    Task.await(task)
  end

  def map(file_name, genotype) do
    ids_n_pids = :ets.new(:ids_n_pids, [:set, :private])
    [cortex | cerebral_units] = genotype
    spawn_cerebral_units(ids_n_pids, Cortex, [cortex.id])
    spawn_cerebral_units(ids_n_pids, Sensor, cortex.sensor_ids)
    spawn_cerebral_units(ids_n_pids, Actuator, cortex.actuator_ids)
    spawn_cerebral_units(ids_n_pids, Neuron, cortex.n_ids)
    link_cerebral_units(cerebral_units, ids_n_pids)
    link_cortex(cortex, ids_n_pids)
    cortex_pid = :ets.lookup_element(ids_n_pids, cortex.id, 2)

    receive do
      {^cortex_pid, :backup, neuron_ids_n_weights} ->
        u_genotype = update_genotype(ids_n_pids, genotype, neuron_ids_n_weights)
        {:ok, file} = :file.open(file_name, :write)
        :lists.foreach(fn x -> :io.format(file, "~p.~n", [x]) end, u_genotype)
        :file.close(file)
        Logger.debug("Finished updating to file: #{file_name}")
    end
  end

  @doc ~S"""
  We spawn the process for each element based on its type: cerebral_unit_type, and
  the gen function that belongs to the cerebral_unit_type module. We then enter
  the {Id, PId} tuple into our ETS table for later use.
  """
  def spawn_cerebral_units(ids_n_pids, cerebral_unit_type, [id | ids]) do
    pid = apply(cerebral_unit_type, :gen, [self()])
    :ets.insert(ids_n_pids, {id, pid})
    :ets.insert(ids_n_pids, {pid, id})
    spawn_cerebral_units(ids_n_pids, cerebral_unit_type, ids)
  end

  def spawn_cerebral_units(_ids_n_pids, _cerebral_unit_type, []) do
    true
  end

  @doc ~S"""
  The link_cerebral_units/2 converts the Ids to PIds using the created IdsNPids
  ETS table. At this point all the elements are spawned, and the processes are
  waiting for their initial states.
  """
  def link_cerebral_units([%Sensor{} = sensor | cerebral_units], ids_n_pids) do
    sensor_pid = :ets.lookup_element(ids_n_pids, sensor.id, 2)
    cortex_pid = :ets.lookup_element(ids_n_pids, sensor.cx_id, 2)
    fanout_pids = for id <- sensor.fanout_ids, do: :ets.lookup_element(ids_n_pids, id, 2)
    send(sensor_pid, {self(), {sensor.id, cortex_pid, sensor.name, sensor.vl, fanout_pids}})
    link_cerebral_units(cerebral_units, ids_n_pids)
  end

  def link_cerebral_units([%Actuator{} = actuator | cerebral_units], ids_n_pids) do
    actuator_pid = :ets.lookup_element(ids_n_pids, actuator.id, 2)
    cortex_pid = :ets.lookup_element(ids_n_pids, actuator.cx_id, 2)
    fanin_pids = for id <- actuator.fanin_ids, do: :ets.lookup_element(ids_n_pids, id, 2)
    send(actuator_pid, {self(), {actuator.id, cortex_pid, actuator.name, fanin_pids}})
    link_cerebral_units(cerebral_units, ids_n_pids)
  end

  def link_cerebral_units([%Neuron{} = neuron | cerebral_units], ids_n_pids) do
    neuron_pid = :ets.lookup_element(ids_n_pids, neuron.id, 2)
    cortex_pid = :ets.lookup_element(ids_n_pids, neuron.cx_id, 2)
    input_pid_ps = convert_id_ps2pid_ps(ids_n_pids, neuron.input_id_ps, [])
    output_pids = for id <- neuron.output_ids, do: :ets.lookup_element(ids_n_pids, id, 2)
    send(neuron_pid, {self(), {neuron.id, cortex_pid, neuron.af, input_pid_ps, output_pids}})
    link_cerebral_units(cerebral_units, ids_n_pids)
  end

  def link_cerebral_units([], _ids_n_pids), do: :ok

  @doc ~S"""
  convert_id_ps2pid_ps/3 converts the IdPs
  tuples into tuples that use PIds instead of Ids, such that the Neuron will
  know which weights are to be associated with which incoming vector signals.
  The last element is the bias, which is added to the list in a non tuple form.
  Afterwards, the list is reversed to take its proper order.
  """
  def convert_id_ps2pid_ps(_ids_n_pids, [{:bias, bias}], acc) do
    Enum.reverse([bias | acc])
  end

  def convert_id_ps2pid_ps(ids_n_pids, [{id, weights} | fanin_id_ps], acc) do
    convert_id_ps2pid_ps(ids_n_pids, fanin_id_ps, [
      {:ets.lookup_element(ids_n_pids, id, 2), weights} | acc
    ])
  end

  @doc ~S"""
  The cortex is initialized to its proper state just as other elements. Because
  we have not yet implemented a learning algorithm for our NN system, we need to
  specify when the NN should shutdown. We do this by specifying the total number
  of cycles the NN should execute before terminating, which is 1000 in this
  case.
  """
  def link_cortex(cortex, ids_n_pids) do
    cortex_pid = :ets.lookup_element(ids_n_pids, cortex.id, 2)
    sensor_pids = for id <- cortex.sensor_ids, do: :ets.lookup_element(ids_n_pids, id, 2)
    actuator_pids = for id <- cortex.actuator_ids, do: :ets.lookup_element(ids_n_pids, id, 2)
    neuron_pids = for id <- cortex.n_ids, do: :ets.lookup_element(ids_n_pids, id, 2)
    send(cortex_pid, {self(), {cortex.id, sensor_pids, actuator_pids, neuron_pids}, 1000})
  end

  @doc ~S"""
  For every {neuron_id, p_id_ps} tuple the update_genotype/3 function extracts the
  neuron with the id: neuron_id, and updates its weights. The convert_p_id_ps2id_ps/3
  performs the conversion from PIds to Ids of every {PId, Weights} tuple in the
  Input_p_id_ps list. The updated genotype is then returned back to the caller.
  """
  def update_genotype(ids_n_pids, genotype, [{neuron_id, p_id_ps} | weight_ps]) do
    Logger.debug("genotype: #{inspect(genotype)}")
    Logger.debug("neuron_id: #{inspect(neuron_id)}")
    ## FIXME: genotype is a list of maps/structs not tuples/records.  Find replacement.
    neuron_index = Enum.find_index(genotype, fn x -> x.id == neuron_id end)
    neuron = Enum.at(genotype, neuron_index)
    # neuron = :lists.keyfind(neuron_id, 2, genotype)
    Logger.debug("p_id_ps: #{inspect(p_id_ps)}")
    input_id_ps = convert_p_id_ps2id_ps(ids_n_pids, p_id_ps, [])
    Logger.debug("neuron: #{inspect(neuron)}")
    updated_neuron = %Neuron{neuron | input_id_ps: input_id_ps}
    updated_genotype = List.replace_at(genotype, neuron_index, updated_neuron)
    Logger.debug("neuron: #{inspect(neuron)}")
    Logger.debug("updated_neuron: #{inspect(updated_neuron)}")
    Logger.debug("genotype: #{inspect(genotype)}")
    Logger.debug("updated_genotype: #{inspect(updated_genotype)}")
    update_genotype(ids_n_pids, updated_genotype, weight_ps)
  end

  def update_genotype(_ids_n_pids, genotype, []) do
    genotype
  end

  def convert_p_id_ps2id_ps(ids_n_pids, [{pid, weights} | input_id_ps], acc) do
    convert_p_id_ps2id_ps(ids_n_pids, input_id_ps, [
      {:ets.lookup_element(ids_n_pids, pid, 2), weights} | acc
    ])
  end

  def convert_p_id_ps2id_ps(_ids_n_pids, [bias], acc) do
    :lists.reverse([{:bias, bias} | acc])
  end
end
