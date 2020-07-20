defmodule NEConstructorTest do
  use ExUnit.Case

  test "creates NN and writes it to disk" do
    tmp_path = Temp.mkdir!("ConstructorTest")
    genome_path = Path.join(tmp_path, "neuroevol.terms")

    assert Automaton.Types.TWEANN.Constructor.construct_genotype(genome_path, :rng, :pts, [1, 3]) ==
             :ok

    assert File.exists?(genome_path)
    File.rm_rf!(tmp_path)
  end
end
