defmodule Automaton.Types.TWEANN.Evolution.Species do
  @moduledoc """
  Represents a species within the NEAT/TWEANN population.
  
  Species are groups of genetically similar networks that compete primarily
  against each other rather than against the entire population. This
  promotes diversity and gives new innovations time to optimize before
  competing with refined solutions from other niches.
  """
  
  defstruct [
    :id,                # Unique identifier for the species
    :members,           # List of genotypes in this species
    :representative,    # Representative genotype used for compatibility testing
    :last_improvement,  # Generation when this species last improved
    :best_fitness,      # Best fitness achieved by any member
    :age                # Age of the species in generations
  ]
  
  @doc """
  Creates a new species with initial members and a representative.
  
  ## Parameters
  - members: Initial list of genotypes in the species
  - representative: The genotype that represents this species
  
  ## Returns
  A new Species struct
  """
  def new(members, representative) do
    %__MODULE__{
      id: generate_species_id(),
      members: members,
      representative: representative,
      last_improvement: 0,
      best_fitness: find_best_fitness(members),
      age: 0
    }
  end
  
  @doc """
  Updates a species after a generation.
  
  ## Parameters
  - species: The species to update
  - generation: Current generation number
  
  ## Returns
  Updated species struct
  """
  def update_after_generation(species, generation) do
    current_best = find_best_fitness(species.members)
    
    %{species |
      age: species.age + 1,
      last_improvement: if(current_best > species.best_fitness, do: generation, else: species.last_improvement),
      best_fitness: max(species.best_fitness, current_best),
      representative: select_new_representative(species)
    }
  end
  
  @doc """
  Checks if a species should be considered stagnant based on improvement history.
  
  ## Parameters
  - species: The species to check
  - current_generation: Current generation number
  - stagnation_threshold: Number of generations without improvement to consider stagnant
  
  ## Returns
  Boolean indicating if the species is stagnant
  """
  def stagnant?(species, current_generation, stagnation_threshold) do
    current_generation - species.last_improvement >= stagnation_threshold
  end
  
  @doc """
  Calculates adjusted fitness for all members in the species based on explicit fitness sharing.
  
  ## Parameters
  - species: The species containing members
  
  ## Returns
  List of members with adjusted fitness values
  """
  def calculate_adjusted_fitness(species) do
    n = length(species.members)
    
    Enum.map(species.members, fn member ->
      %{member | adjusted_fitness: member.fitness / n}
    end)
  end
  
  # Private helper functions
  
  defp generate_species_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16()
  end
  
  defp find_best_fitness(members) do
    case members do
      [] -> 0.0
      _ -> Enum.max_by(members, & &1.fitness).fitness
    end
  end
  
  defp select_new_representative(species) do
    # Randomly select member to be the new representative
    Enum.random(species.members)
  end
end