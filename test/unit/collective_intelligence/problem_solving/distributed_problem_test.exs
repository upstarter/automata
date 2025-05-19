defmodule Automata.CollectiveIntelligence.ProblemSolving.DistributedProblemTest do
  use ExUnit.Case, async: true
  
  alias Automata.CollectiveIntelligence.ProblemSolving.DistributedProblem
  alias Automata.CollectiveIntelligence.ProblemSolving.ProblemManager
  alias Automata.CollectiveIntelligence.ProblemSolving.Optimization
  alias Automata.CollectiveIntelligence.ProblemSolving.Search
  alias Automata.CollectiveIntelligence.ProblemSolving.Planning
  alias Automata.CollectiveIntelligence.ProblemSolving.ConstraintSatisfaction
  alias Automata.CollectiveIntelligence.ProblemSolving.DistributedComputation
  
  # Setup Registry for tests
  setup do
    # Start Registry
    {:ok, _pid} = Registry.start_link(keys: :unique, name: Automata.Registry)
    
    # Start ProblemManager
    {:ok, manager_pid} = ProblemManager.start_link()
    
    %{manager_pid: manager_pid}
  end
  
  describe "optimization problems" do
    test "minimize function", %{manager_pid: _manager_pid} do
      # Define a simple optimization problem to minimize a function
      config = %{
        id: "test_optimization_1",
        name: "Simple Minimization",
        description: "Minimize x^2 + y^2",
        domain_space: %{
          "x" => {-10.0, 10.0},
          "y" => {-10.0, 10.0}
        },
        objective_function: fn solution ->
          x = solution["x"]
          y = solution["y"]
          x * x + y * y
        end,
        constraints: [
          %{type: :inequality, lhs: {:add, {:mul, {:var, "x"}, {:var, "x"}}, {:mul, {:var, "y"}, {:var, "y"}}}, rhs: {:const, 100.0}}
        ],
        custom_parameters: %{
          optimization_method: :gradient_descent,
          learning_rate: 0.1,
          minimize: true
        }
      }
      
      # Create the problem
      {:ok, problem_id} = ProblemManager.create_problem(:optimization, config)
      
      # Register solvers
      {:ok, :registered} = DistributedProblem.register_solver(problem_id, "solver1", %{})
      {:ok, :registered} = DistributedProblem.register_solver(problem_id, "solver2", %{})
      
      # Submit partial solutions (simulating optimization steps)
      solution1 = %{
        type: :complete_plan,
        plan: [
          %{action: "initialize", params: %{"x" => 5.0, "y" => 5.0}},
          %{action: "gradient_step", params: %{"x" => 3.0, "y" => 3.0}},
          %{action: "gradient_step", params: %{"x" => 1.0, "y" => 1.0}},
          %{action: "gradient_step", params: %{"x" => 0.5, "y" => 0.5}},
          %{action: "gradient_step", params: %{"x" => 0.1, "y" => 0.1}}
        ],
        quality: 0.02  # x^2 + y^2 for x=0.1, y=0.1
      }
      
      solution2 = %{
        type: :complete_plan,
        plan: [
          %{action: "initialize", params: %{"x" => -5.0, "y" => -5.0}},
          %{action: "gradient_step", params: %{"x" => -3.0, "y" => -3.0}},
          %{action: "gradient_step", params: %{"x" => -1.0, "y" => -1.0}},
          %{action: "gradient_step", params: %{"x" => -0.5, "y" => -0.5}},
          %{action: "gradient_step", params: %{"x" => -0.2, "y" => -0.2}}
        ],
        quality: 0.08  # x^2 + y^2 for x=-0.2, y=-0.2
      }
      
      {:ok, :submitted} = DistributedProblem.submit_partial_solution(problem_id, "solver1", solution1)
      {:ok, :submitted} = DistributedProblem.submit_partial_solution(problem_id, "solver2", solution2)
      
      # Check status
      {:ok, state, _status_info} = DistributedProblem.get_status(problem_id)
      assert state in [:solving, :verifying]
      
      # Close the problem
      {:ok, :closed} = DistributedProblem.close_problem(problem_id)
      
      # Get problem info
      {:ok, problem_info} = ProblemManager.get_problem_info(problem_id)
      assert problem_info.state in [:solved, :closed]
    end
  end
  
  describe "search problems" do
    test "path finding search", %{manager_pid: _manager_pid} do
      # Define a simple search problem
      config = %{
        id: "test_search_1",
        name: "Simple Path Finding",
        description: "Find path in a simple graph",
        domain_space: %{
          :type => :graph,
          :nodes => ["A", "B", "C", "D", "E"],
          :edges => [{"A", "B"}, {"A", "C"}, {"B", "D"}, {"C", "D"}, {"D", "E"}]
        },
        custom_parameters: %{
          search_strategy: :a_star,
          initial_state: "A",
          goal_state: "E",
          heuristic: fn node ->
            # Simple heuristic based on node identity
            case node do
              "A" -> 3
              "B" -> 2
              "C" -> 2
              "D" -> 1
              "E" -> 0
            end
          end
        }
      }
      
      # Create the problem
      {:ok, problem_id} = ProblemManager.create_problem(:search, config)
      
      # Register solvers
      {:ok, :registered} = DistributedProblem.register_solver(problem_id, "solver1", %{})
      
      # Submit a solution (path)
      solution = %{
        type: :path,
        path: ["A", "B", "D", "E"],
        cost: 3
      }
      
      {:ok, :submitted} = DistributedProblem.submit_partial_solution(problem_id, "solver1", solution)
      
      # Check status
      {:ok, state, _status_info} = DistributedProblem.get_status(problem_id)
      assert state in [:solving, :verifying, :solved]
      
      # Close the problem
      {:ok, :closed} = DistributedProblem.close_problem(problem_id)
      
      # Get problem info
      {:ok, problem_info} = ProblemManager.get_problem_info(problem_id)
      assert problem_info.state in [:solved, :closed]
    end
  end
  
  describe "planning problems" do
    test "simple planning problem", %{manager_pid: _manager_pid} do
      # Define a simple planning problem
      config = %{
        id: "test_planning_1",
        name: "Simple Planning",
        description: "Block world planning",
        custom_parameters: %{
          planning_approach: :classical,
          initial_state: %{
            "block_a" => "table",
            "block_b" => "table",
            "block_c" => "table",
            "clear_a" => true,
            "clear_b" => true,
            "clear_c" => true
          },
          goal_specification: fn state ->
            Map.get(state, "block_a") == "block_b" and
            Map.get(state, "block_b") == "block_c" and
            Map.get(state, "block_c") == "table"
          end,
          actions: [
            %{
              name: "move",
              params: [:block, :from, :to],
              preconditions: fn state, %{block: block, from: from, to: to} ->
                Map.get(state, "block_#{block}") == from and
                Map.get(state, "clear_#{block}", false) and
                (to == "table" or Map.get(state, "clear_#{to}", false))
              end,
              effects: fn state, %{block: block, from: from, to: to} ->
                state
                |> Map.put("block_#{block}", to)
                |> Map.put("clear_#{from}", true)
                |> Map.update("clear_#{to}", nil, fn _ -> false end)
              end
            }
          ]
        }
      }
      
      # Create the problem
      {:ok, problem_id} = ProblemManager.create_problem(:planning, config)
      
      # Register solvers
      {:ok, :registered} = DistributedProblem.register_solver(problem_id, "solver1", %{})
      
      # Submit a solution (plan)
      solution = %{
        type: :complete_plan,
        plan: [
          %{action: "move", block: "a", from: "table", to: "b"},
          %{action: "move", block: "b", from: "table", to: "c"}
        ],
        quality: 2  # Plan length
      }
      
      {:ok, :submitted} = DistributedProblem.submit_partial_solution(problem_id, "solver1", solution)
      
      # Check status
      {:ok, state, _status_info} = DistributedProblem.get_status(problem_id)
      assert state in [:solving, :verifying, :solved]
      
      # Close the problem
      {:ok, :closed} = DistributedProblem.close_problem(problem_id)
      
      # Get problem info
      {:ok, problem_info} = ProblemManager.get_problem_info(problem_id)
      assert problem_info.state in [:solved, :closed]
    end
  end
  
  describe "constraint satisfaction problems" do
    test "simple CSP", %{manager_pid: _manager_pid} do
      # Define a simple CSP
      config = %{
        id: "test_csp_1",
        name: "Simple CSP",
        description: "Map coloring problem",
        custom_parameters: %{
          csp_technique: :backtracking,
          variables: ["WA", "NT", "SA", "Q", "NSW", "V", "T"],
          domains: %{
            "WA" => [:red, :green, :blue],
            "NT" => [:red, :green, :blue],
            "SA" => [:red, :green, :blue],
            "Q" => [:red, :green, :blue],
            "NSW" => [:red, :green, :blue],
            "V" => [:red, :green, :blue],
            "T" => [:red, :green, :blue]
          },
          constraints: [
            {"WA", "NT", :neq},
            {"WA", "SA", :neq},
            {"NT", "SA", :neq},
            {"NT", "Q", :neq},
            {"SA", "Q", :neq},
            {"SA", "NSW", :neq},
            {"SA", "V", :neq},
            {"Q", "NSW", :neq},
            {"NSW", "V", :neq}
          ]
        }
      }
      
      # Create the problem
      {:ok, problem_id} = ProblemManager.create_problem(:constraint_satisfaction, config)
      
      # Register solvers
      {:ok, :registered} = DistributedProblem.register_solver(problem_id, "solver1", %{})
      
      # Submit a solution (assignment)
      solution = %{
        type: :complete_assignment,
        assignment: %{
          "WA" => :red,
          "NT" => :green,
          "SA" => :blue,
          "Q" => :red,
          "NSW" => :green,
          "V" => :red,
          "T" => :green
        }
      }
      
      {:ok, :submitted} = DistributedProblem.submit_partial_solution(problem_id, "solver1", solution)
      
      # Check status
      {:ok, state, _status_info} = DistributedProblem.get_status(problem_id)
      assert state in [:solving, :verifying, :solved]
      
      # Close the problem
      {:ok, :closed} = DistributedProblem.close_problem(problem_id)
      
      # Get problem info
      {:ok, problem_info} = ProblemManager.get_problem_info(problem_id)
      assert problem_info.state in [:solved, :closed]
    end
  end
  
  describe "distributed computation problems" do
    test "map reduce computation", %{manager_pid: _manager_pid} do
      # Define a distributed computation problem
      config = %{
        id: "test_compute_1",
        name: "Word Count",
        description: "Count word occurrences in text",
        custom_parameters: %{
          computation_paradigm: :map_reduce,
          input_data: "the quick brown fox jumps over the lazy dog. the dog remains lazy.",
          processing_function: fn chunk ->
            String.split(chunk, ~r/\s+/)
            |> Enum.filter(fn word -> String.length(word) > 0 end)
            |> Enum.map(fn word ->
              # Remove punctuation and convert to lowercase
              word = word
                |> String.replace(~r/[^\w]/, "")
                |> String.downcase()
              {word, 1}
            end)
          end,
          reduction_function: fn mapped_results ->
            # Flatten all mapped results
            flatten_results = List.flatten(mapped_results)
            
            # Group by word and sum counts
            Enum.reduce(flatten_results, %{}, fn {word, count}, acc ->
              Map.update(acc, word, count, &(&1 + count))
            end)
          end
        }
      }
      
      # Create the problem
      {:ok, problem_id} = ProblemManager.create_problem(:distributed_computation, config)
      
      # Register solvers
      {:ok, :registered} = DistributedProblem.register_solver(problem_id, "mapper1", %{})
      {:ok, :registered} = DistributedProblem.register_solver(problem_id, "mapper2", %{})
      {:ok, :registered} = DistributedProblem.register_solver(problem_id, "reducer", %{})
      
      # Submit partial solutions
      mapper1_solution = %{
        type: :processed_partition,
        partition_id: "partition_0",
        result: [{"the", 1}, {"quick", 1}, {"brown", 1}, {"fox", 1}]
      }
      
      mapper2_solution = %{
        type: :processed_partition,
        partition_id: "partition_1",
        result: [{"jumps", 1}, {"over", 1}, {"the", 1}, {"lazy", 1}, {"dog", 1}]
      }
      
      reduce_solution = %{
        type: :final_result,
        result: %{
          "the" => 2,
          "quick" => 1,
          "brown" => 1,
          "fox" => 1,
          "jumps" => 1,
          "over" => 1,
          "lazy" => 2,
          "dog" => 2,
          "remains" => 1
        }
      }
      
      {:ok, :submitted} = DistributedProblem.submit_partial_solution(problem_id, "mapper1", mapper1_solution)
      {:ok, :submitted} = DistributedProblem.submit_partial_solution(problem_id, "mapper2", mapper2_solution)
      {:ok, :submitted} = DistributedProblem.submit_partial_solution(problem_id, "reducer", reduce_solution)
      
      # Check status
      {:ok, state, _status_info} = DistributedProblem.get_status(problem_id)
      assert state in [:solving, :verifying, :solved]
      
      # Close the problem
      {:ok, :closed} = DistributedProblem.close_problem(problem_id)
      
      # Get problem info
      {:ok, problem_info} = ProblemManager.get_problem_info(problem_id)
      assert problem_info.state in [:solved, :closed]
    end
  end
  
  describe "problem manager operations" do
    test "list problems returns correct summaries", %{manager_pid: _manager_pid} do
      # Create multiple problems
      {:ok, id1} = ProblemManager.create_problem(:optimization, %{
        id: "test_list_opt",
        name: "Optimization Problem",
        description: "Test optimization problem",
        domain_space: %{"x" => {0, 10}},
        objective_function: fn solution -> solution["x"] end,
        custom_parameters: %{optimization_method: :gradient_descent}
      })
      
      {:ok, id2} = ProblemManager.create_problem(:search, %{
        id: "test_list_search",
        name: "Search Problem",
        description: "Test search problem",
        domain_space: %{:type => :graph},
        custom_parameters: %{
          search_strategy: :a_star,
          initial_state: "A",
          goal_state: "B"
        }
      })
      
      # List problems
      {:ok, problems} = ProblemManager.list_problems()
      
      # Verify both problems are listed
      assert length(problems) == 2
      assert Enum.any?(problems, fn p -> p.id == id1 end)
      assert Enum.any?(problems, fn p -> p.id == id2 end)
      
      # Verify problem summaries have correct types
      prob1 = Enum.find(problems, fn p -> p.id == id1 end)
      prob2 = Enum.find(problems, fn p -> p.id == id2 end)
      
      assert prob1.type == :optimization
      assert prob2.type == :search
    end
    
    test "filter problems by criteria", %{manager_pid: _manager_pid} do
      # Create multiple problems
      {:ok, _id1} = ProblemManager.create_problem(:optimization, %{
        id: "test_filter_opt",
        name: "Optimization Problem",
        description: "Test optimization filtering",
        domain_space: %{"x" => {0, 10}},
        objective_function: fn solution -> solution["x"] end,
        custom_parameters: %{optimization_method: :gradient_descent}
      })
      
      {:ok, _id2} = ProblemManager.create_problem(:search, %{
        id: "test_filter_search",
        name: "Search Problem",
        description: "Test search filtering",
        domain_space: %{:type => :graph},
        custom_parameters: %{
          search_strategy: :a_star,
          initial_state: "A",
          goal_state: "B"
        }
      })
      
      # Filter problems by type
      {:ok, optimization_problems} = ProblemManager.filter_problems(%{type: :optimization})
      {:ok, search_problems} = ProblemManager.filter_problems(%{type: :search})
      
      # Verify filtering works
      assert length(optimization_problems) == 1
      assert length(search_problems) == 1
      assert hd(optimization_problems).type == :optimization
      assert hd(search_problems).type == :search
      
      # Filter by description content
      {:ok, opt_filter_problems} = ProblemManager.filter_problems(%{description_contains: "optimization"})
      assert length(opt_filter_problems) == 1
      assert hd(opt_filter_problems).description =~ "optimization"
    end
    
    test "get problem info returns detailed information", %{manager_pid: _manager_pid} do
      # Create a problem
      config = %{
        id: "test_info_problem",
        name: "Problem Info Test",
        description: "Testing problem info retrieval",
        domain_space: %{"x" => {0, 10}},
        objective_function: fn solution -> solution["x"] end,
        custom_parameters: %{optimization_method: :gradient_descent}
      }
      
      {:ok, problem_id} = ProblemManager.create_problem(:optimization, config)
      
      # Register solvers
      {:ok, :registered} = DistributedProblem.register_solver(problem_id, "info_solver1", %{})
      {:ok, :registered} = DistributedProblem.register_solver(problem_id, "info_solver2", %{})
      
      # Get problem info
      {:ok, info} = ProblemManager.get_problem_info(problem_id)
      
      # Verify info contains expected details
      assert info.id == problem_id
      assert info.type == :optimization
      assert info.state == :solving
      assert info.config.name == "Problem Info Test"
    end
  end
end