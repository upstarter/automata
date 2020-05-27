defmodule WorldConfigTest do
  use ExUnit.Case, async: true

  describe "defaults" do
    test "world" do
      assert %WorldConfig{}.world == nil
    end

    test "evirons" do
      assert %WorldConfig{}.environs == nil
    end

    test "ontology" do
      assert %WorldConfig{}.ontology == nil
    end

    test "automata_config" do
      assert %WorldConfig{}.automata_config == nil
    end
  end
end
