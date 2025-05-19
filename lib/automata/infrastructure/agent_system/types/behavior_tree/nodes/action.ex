defmodule Automata.Infrastructure.AgentSystem.Types.BehaviorTree.Nodes.Action do
  @moduledoc """
  Action node for behavior trees.
  
  An action node represents an executable action that the agent can perform.
  It can succeed, fail, or stay running across multiple ticks.
  """
  
  use Automata.Infrastructure.AgentSystem.Types.BehaviorTree.NodeType
  require Logger
  alias Automata.Infrastructure.Resilience.Logger, as: EnhancedLogger
  
  @impl true
  def init(config) do
    # Get action handler from settings
    action_handler = Map.get(config.settings, :action_handler)
    
    # Validate action handler
    if is_nil(action_handler) do
      {:error, "Action node requires an action_handler in settings"}
    else
      # Create initial state
      state = %{
        status: :bh_fresh,
        action_handler: action_handler,
        action_name: Map.get(config.settings, :action_name, "unnamed_action"),
        parameters: Map.get(config.settings, :parameters, %{}),
        result: nil,
        started_at: nil,
        execution_count: 0
      }
      
      {:ok, state}
    end
  end
  
  @impl true
  def evaluate(state, context) do
    case state.status do
      :bh_fresh ->
        # Starting a new action
        start_action(state, context)
        
      :bh_running ->
        # Check if action is still running
        check_action_status(state, context)
        
      terminal_status when terminal_status in [:bh_success, :bh_failure] ->
        # Action already completed
        {
          terminal_status,
          state,
          context.blackboard
        }
    end
  end
  
  @impl true
  def reset(state) do
    {:ok, %{state |
      status: :bh_fresh,
      result: nil,
      started_at: nil
    }}
  end
  
  # Private helpers
  
  defp start_action(state, context) do
    EnhancedLogger.debug("Starting action", %{
      action: state.action_name,
      parameters: state.parameters
    })
    
    # Get the action handler
    action_handler = resolve_action_handler(state.action_handler)
    
    # Check if action handler exists
    if is_nil(action_handler) do
      EnhancedLogger.error("Action handler not found", %{
        action_handler: state.action_handler,
        action: state.action_name
      })
      
      {
        :bh_failure,
        %{state |
          status: :bh_failure,
          result: {:error, :handler_not_found}
        },
        context.blackboard
      }
    else
      # Execute action handler
      action_context = %{
        blackboard: context.blackboard,
        parameters: state.parameters,
        agent_id: context.agent_id,
        world_id: context.world_id
      }
      
      try do
        case action_handler.start(action_context) do
          {:ok, action_id} ->
            # Action started successfully
            {
              :bh_running,
              %{state |
                status: :bh_running,
                started_at: DateTime.utc_now(),
                execution_count: state.execution_count + 1,
                result: %{action_id: action_id}
              },
              context.blackboard
            }
            
          {:ok, action_id, updates} when is_map(updates) ->
            # Action started with blackboard updates
            {
              :bh_running,
              %{state |
                status: :bh_running,
                started_at: DateTime.utc_now(),
                execution_count: state.execution_count + 1,
                result: %{action_id: action_id}
              },
              Map.merge(context.blackboard, updates)
            }
            
          {:complete, :success, updates} when is_map(updates) ->
            # Action completed immediately with success
            {
              :bh_success,
              %{state |
                status: :bh_success,
                started_at: DateTime.utc_now(),
                execution_count: state.execution_count + 1,
                result: %{immediate: true, status: :success}
              },
              Map.merge(context.blackboard, updates)
            }
            
          {:complete, :failure, reason} ->
            # Action completed immediately with failure
            EnhancedLogger.debug("Action failed immediately", %{
              action: state.action_name,
              reason: reason
            })
            
            {
              :bh_failure,
              %{state |
                status: :bh_failure,
                started_at: DateTime.utc_now(),
                execution_count: state.execution_count + 1,
                result: %{immediate: true, status: :failure, reason: reason}
              },
              context.blackboard
            }
            
          {:error, reason} ->
            # Action failed to start
            EnhancedLogger.warning("Action failed to start", %{
              action: state.action_name,
              reason: reason
            })
            
            {
              :bh_failure,
              %{state |
                status: :bh_failure,
                execution_count: state.execution_count + 1,
                result: {:error, reason}
              },
              context.blackboard
            }
        end
      rescue
        e ->
          # Exception during action execution
          EnhancedLogger.error("Exception in action handler", %{
            action: state.action_name,
            error: Exception.message(e),
            stacktrace: Exception.format_stacktrace(__STACKTRACE__)
          })
          
          {
            :bh_failure,
            %{state |
              status: :bh_failure,
              execution_count: state.execution_count + 1,
              result: {:exception, Exception.message(e)}
            },
            context.blackboard
          }
      end
    end
  end
  
  defp check_action_status(state, context) do
    EnhancedLogger.debug("Checking action status", %{
      action: state.action_name,
      started_at: state.started_at
    })
    
    # Get the action handler
    action_handler = resolve_action_handler(state.action_handler)
    
    # Check if action handler exists
    if is_nil(action_handler) do
      EnhancedLogger.error("Action handler not found during status check", %{
        action_handler: state.action_handler,
        action: state.action_name
      })
      
      {
        :bh_failure,
        %{state |
          status: :bh_failure,
          result: Map.put(state.result || %{}, :error, :handler_not_found)
        },
        context.blackboard
      }
    else
      # Get action ID from result
      action_id = get_in(state.result, [:action_id])
      
      if is_nil(action_id) do
        EnhancedLogger.error("Action ID not found during status check", %{
          action: state.action_name
        })
        
        {
          :bh_failure,
          %{state |
            status: :bh_failure,
            result: Map.put(state.result || %{}, :error, :action_id_missing)
          },
          context.blackboard
        }
      else
        # Check action status
        action_context = %{
          blackboard: context.blackboard,
          parameters: state.parameters,
          agent_id: context.agent_id,
          world_id: context.world_id,
          action_id: action_id
        }
        
        try do
          case action_handler.check_status(action_context) do
            {:running, _updates} ->
              # Action still running
              {
                :bh_running,
                state,
                context.blackboard
              }
              
            {:complete, :success, updates} when is_map(updates) ->
              # Action completed successfully with updates
              EnhancedLogger.debug("Action completed successfully", %{
                action: state.action_name
              })
              
              {
                :bh_success,
                %{state |
                  status: :bh_success,
                  result: Map.put(state.result, :completion, %{
                    status: :success,
                    timestamp: DateTime.utc_now()
                  })
                },
                Map.merge(context.blackboard, updates)
              }
              
            {:complete, :success} ->
              # Action completed successfully
              EnhancedLogger.debug("Action completed successfully", %{
                action: state.action_name
              })
              
              {
                :bh_success,
                %{state |
                  status: :bh_success,
                  result: Map.put(state.result, :completion, %{
                    status: :success,
                    timestamp: DateTime.utc_now()
                  })
                },
                context.blackboard
              }
              
            {:complete, :failure, reason} ->
              # Action completed with failure
              EnhancedLogger.debug("Action failed", %{
                action: state.action_name,
                reason: reason
              })
              
              {
                :bh_failure,
                %{state |
                  status: :bh_failure,
                  result: Map.put(state.result, :completion, %{
                    status: :failure,
                    reason: reason,
                    timestamp: DateTime.utc_now()
                  })
                },
                context.blackboard
              }
              
            {:error, reason} ->
              # Error checking action status
              EnhancedLogger.warning("Error checking action status", %{
                action: state.action_name,
                reason: reason
              })
              
              {
                :bh_failure,
                %{state |
                  status: :bh_failure,
                  result: Map.put(state.result, :error, reason)
                },
                context.blackboard
              }
          end
        rescue
          e ->
            # Exception during status check
            EnhancedLogger.error("Exception checking action status", %{
              action: state.action_name,
              error: Exception.message(e),
              stacktrace: Exception.format_stacktrace(__STACKTRACE__)
            })
            
            {
              :bh_failure,
              %{state |
                status: :bh_failure,
                result: Map.put(state.result || %{}, :exception, Exception.message(e))
              },
              context.blackboard
            }
        end
      end
    end
  end
  
  defp resolve_action_handler(handler) when is_atom(handler) do
    # Handler is already a module
    if Code.ensure_loaded?(handler) do
      handler
    else
      nil
    end
  end
  
  defp resolve_action_handler(handler) when is_binary(handler) do
    # Handler is a string, try to convert to module
    try do
      String.to_existing_atom("Elixir.#{handler}")
    rescue
      ArgumentError -> nil
    end
  end
  
  defp resolve_action_handler(_), do: nil
end