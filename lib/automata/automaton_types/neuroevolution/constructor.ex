defmodule Automaton.Types.TWEANN.Constructor do
  alias Automaton.Types.TWEANN.Sensor
  alias Automaton.Types.TWEANN.Actuator
  alias Automaton.Types.TWEANN.Cortex
  alias Automaton.Types.TWEANN.Neuron

  @doc """
  The `construct_genotype` function accepts the name of the file to which we'll
  save the genotype, sensor name, actuator name, and the hidden layer density
  parameters. We have to generate unique Ids for every sensor and actuator. The
  sensor and actuator names are used as input to the create_sensor and
  create_actuator functions, which in turn generate the actual Sensor and
  Actuator representing tuples. We create unique Ids for sensors and actuators
  so that when in the future a NN uses 2 or more sensors or actuators of the
  same type, we will be able to differentiate between them using their ids.
  After the Sensor and Actuator tuples are generated, we extract the NN’s input
  and output vector lengths from the sensor and actuator used by the system. The
  Input_VL is then used to specify how many weights the neurons in the input
  layer will need, and the Output_VL specifies how many neurons are in the
  output layer of the NN. After appending the HiddenLayerDensites to the now
  known number of neurons in the last layer to generate the full LayerDensities
  list, we use the create_NeuroLayers function to generate the Neuron
  representing tuples. We then update the Sensor and Actuator records with
  proper fanin and fanout ids from the freshly created Neuron tuples, compose
  the Cortex, and write the genotype to file.
  """
  def construct_genotype(sensor_name, actuator_name, hidden_layer_densities) do
    construct_genotype(:neuro, sensor_name, actuator_name, hidden_layer_densities)
  end

  def construct_genotype(file_name, sensor_name, actuator_name, hidden_layer_densities) do
    sensor = create_sensor(sensor_name)
    actuator = create_actuator(actuator_name)
    output_vl = actuator.vl
    layer_densities = List.insert_at(hidden_layer_densities, -1, output_vl)
    cx_id = {:cortex, generate_id()}
    neurons = create_neuro_layers(cx_id, sensor, actuator, layer_densities)
    input_layer = List.first(neurons)
    output_layer = List.last(neurons)
    fl_nids = Enum.map(input_layer, fn n -> n.id end)
    ll_nids = Enum.map(output_layer, fn n -> n.id end)
    n_ids = for n <- List.flatten(neurons), do: n.id
    sensor = %Sensor{sensor | cx_id: cx_id, fanout_ids: fl_nids}
    actuator = %Actuator{actuator | cx_id: cx_id, fanin_ids: ll_nids}
    cortex = create_cortex(cx_id, [sensor.id], [actuator.id], n_ids)
    genotype = List.flatten([cortex, sensor, actuator | neurons])
    {:ok, file} = :file.open(file_name, :write)
    :lists.foreach(fn x -> :io.format(file, "~p.~n", [x]) end, genotype)
    :file.close(file)
  end

  @doc """
  Every sensor and actuator uses some kind of function associated with it, a
  function that either polls the environment for sensory signals (in the case of
  a sensor) or acts upon the environment (in the case of an actuator). It is the
  function that we need to define and program before it is used, and the name of
  the function is the same as the name of the sensor or actuator itself. For
  example, the create_sensor/1 has specified only the rng sensor, because that
  is the only sensor function we’ve finished developing. The rng function has
  its own vl specification, which will determine the number of weights that a
  neuron will need to allocate if it is to accept this sensor's output vector.
  The same principles apply to the create_actuator function. Both, create_sensor
  and create_actuator function, given the name of the sensor or actuator, will
  return a record with all the specifications of that element, each with its own
  unique Id.
  """
  def create_sensor(name) do
    case name do
      :rng ->
        %Sensor{id: {:sensor, generate_id()}, name: :rng, vl: 2}

      _ ->
        exit("System does not yet support a sensor by the name #{name}")
    end
  end

  def create_actuator(name) do
    case name do
      :pts ->
        %Actuator{id: {:actuator, generate_id()}, name: :pts, vl: 1}

      _ ->
        exit("System does not yet support a actuator by the name #{name}")
    end
  end

  @doc """
  The function create_neuro_layers/3 prepares the initial step before starting
  the recursive create_neuro_layers/7 function which will create all the Neuron
  records. We first generate the place holder Input Ids "Plus" (Input_IdPs),
  which are tuples composed of Ids and the vector lengths of the incoming
  signals associated with them. The proper input_idps will have a weight list in
  the tuple instead of the vector length. Because we are only building NNs each
  with only a single Sensor and Actuator, the IdP to the first layer is composed
  of the single Sensor Id with the vector length of its sensory signal, likewise
  in the case of the Actuator. We then generate unique ids for the neurons in
  the first layer, and drop into the recursive create_neuro_layers/7 function.
  """
  def create_neuro_layers(cx_id, sensor, actuator, layer_densities) do
    input_id_ps = [{sensor.id, sensor.vl}]
    tot_layers = length(layer_densities)
    [fl_neurons | next_lds] = layer_densities
    n_ids = for id <- generate_ids(fl_neurons, []), do: {:neuron, {1, id}}
    create_neuro_layers(cx_id, actuator.id, 1, tot_layers, input_id_ps, n_ids, next_lds, [])
  end

  def create_neuro_layers(
        cx_id,
        actuator_id,
        layer_index,
        tot_layers,
        input_id_ps,
        n_ids,
        [next_ld | lds],
        acc
      ) do
    output_nids = for id <- generate_ids(next_ld, []), do: {:neuron, {layer_index + 1, id}}
    layer_neurons = create_neuro_layer(cx_id, input_id_ps, n_ids, output_nids, [])
    next_input_id_ps = for n_id <- n_ids, do: {n_id, 1}

    create_neuro_layers(
      cx_id,
      actuator_id,
      layer_index + 1,
      tot_layers,
      next_input_id_ps,
      output_nids,
      lds,
      [layer_neurons | acc]
    )
  end

  def create_neuro_layers(cx_id, actuator_id, tot_layers, tot_layers, input_id_ps, nids, [], acc) do
    output_ids = [actuator_id]
    layer_neurons = create_neuro_layer(cx_id, input_id_ps, nids, output_ids, [])
    Enum.reverse([layer_neurons | acc])
  end

  @doc """
  To create neurons from the same layer, all that is needed are the Ids for
  those neurons, a list of Input_IdPs for every neuron so that we can create the
  proper number of weights, and a list of Output_Ids. Since in our simple feed
  forward neural network all neurons are fully connected to the neurons in the
  next layer, the Input_IdPs and Output_Ids are the same for every neuron be-
  longing to the same layer.
  """
  def create_neuro_layer(cx_id, input_id_ps, [id | n_ids], output_ids, acc) do
    neuron = create_neuron(input_id_ps, id, cx_id, output_ids)
    create_neuro_layer(cx_id, input_id_ps, n_ids, output_ids, [neuron | acc])
  end

  def create_neuro_layer(_cx_id, _input_id_ps, [], _output_ids, acc), do: acc

  @doc """
  Each neuron record is composed by the `create_neuron/3` function. The
  `create_neuron/3` function creates the Input list from the tuples
  [{Id,Weights}...] using the vector lengths specified in the place holder
  Input_IdPs. The `create_neural_input/2` function uses `create_neural_weights/2` to
  generate the random weights in the range of -0.5 to 0.5, adding the bias to
  the end of the list.
  """
  def create_neuron(input_id_ps, id, cx_id, output_ids) do
    proper_input_id_ps = create_neural_input(input_id_ps, [])

    %Neuron{
      id: id,
      cx_id: cx_id,
      af: :tanh,
      input_id_ps: proper_input_id_ps,
      output_ids: output_ids
    }
  end

  def create_neural_input([{input_id, input_vl} | input_id_ps], acc) do
    weights = create_neural_weights(input_vl, [])
    create_neural_input(input_id_ps, [{input_id, weights} | acc])
  end

  def create_neural_input([], acc) do
    Enum.reverse([{:bias, :rand.uniform() - 0.5} | acc])
  end

  def create_neural_weights(0, acc), do: acc

  def create_neural_weights(index, acc) do
    w = :rand.uniform() - 0.5
    create_neural_weights(index - 1, [w | acc])
  end

  @doc """
  The `generate_id/0` creates a unique Id using current time, the Id is a floating
  point value. The `generate_ids/2` function creates a list of unique Ids.
  """
  def generate_ids(0, acc), do: acc

  def generate_ids(index, acc) do
    id = generate_id()
    generate_ids(index - 1, [id | acc])
  end

  def generate_id() do
    Ksuid.generate()
  end

  @doc """
  The `create_cortex/4` function generates the record encoded genotypical
  representation of the cortex element. The Cortex element needs to know the Id
  of every Neuron, Sensor, and Actuator in the NN
  """
  def create_cortex(cx_id, s_ids, a_ids, n_ids) do
    %Cortex{id: cx_id, sensor_ids: s_ids, actuator_ids: a_ids, n_ids: n_ids}
  end
end
