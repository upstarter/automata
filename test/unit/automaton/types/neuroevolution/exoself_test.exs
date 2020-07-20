defmodule NEExoSelfTest do
  use ExUnit.Case

  test "load example genome file" do
    tmp_path = Temp.mkdir!("ExoselfTest")
    genome_path = Path.join(tmp_path, "neuro.terms")
    File.cp(Path.join(__DIR__, "output.terms"), genome_path)
    assert Automaton.Types.TWEANN.ExoSelf.map(genome_path) == :ok
  end
end
