defmodule Automata.Infrastructure.Performance.Supervisor do
  @moduledoc """
  Supervisor for performance-related services in the Automata system.
  
  This supervisor manages:
  - Metrics collection
  - Rate limiting
  - Performance optimization
  - Benchmarking services
  
  These services work together to monitor and optimize system performance.
  """
  
  use Supervisor
  require Logger
  alias Automata.Infrastructure.Resilience.Logger, as: EnhancedLogger
  
  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end
  
  @impl true
  def init(_init_arg) do
    EnhancedLogger.info("Starting Performance Supervisor")
    
    children = [
      # Metrics Collector
      Automata.Infrastructure.Performance.MetricsCollector,
      
      # Rate Limiter
      Automata.Infrastructure.Performance.RateLimiter,
      
      # Performance Optimizer (to be started after metrics and rate limiter)
      {Task, fn -> 
        # Let the metrics collector and rate limiter start first
        Process.sleep(1000)
        Automata.Infrastructure.Performance.Optimizer.init()
      end}
    ]
    
    Supervisor.init(children, strategy: :one_for_one)
  end
  
  @doc """
  Gets a summary of the performance system status.
  """
  def status do
    %{
      metrics_collector: metrics_collector_status(),
      rate_limiter: rate_limiter_status(),
      optimizer: optimizer_status()
    }
  end
  
  # Private helpers
  
  defp metrics_collector_status do
    if Process.whereis(Automata.Infrastructure.Performance.MetricsCollector) do
      # Get metrics snapshot
      snapshot = Automata.Infrastructure.Performance.MetricsCollector.get_performance_snapshot()
      
      # Return status info
      %{
        status: :running,
        system: snapshot.system,
        metrics_count: map_size(snapshot.latency) + map_size(snapshot.throughput)
      }
    else
      %{status: :not_running}
    end
  end
  
  defp rate_limiter_status do
    if Process.whereis(Automata.Infrastructure.Performance.RateLimiter) do
      # Try to get stats for some standard limiters
      limiters = ["system_writes", "system_reads", "agent_updates"]
      
      # Collect stats for each
      limiter_stats = Enum.map(limiters, fn name ->
        case Automata.Infrastructure.Performance.RateLimiter.get_stats(name) do
          {:ok, stats} -> {name, stats}
          _ -> {name, nil}
        end
      end)
      |> Enum.reject(fn {_, stats} -> is_nil(stats) end)
      |> Map.new()
      
      # Return status info
      %{
        status: :running,
        limiters: limiter_stats
      }
    else
      %{status: :not_running}
    end
  end
  
  defp optimizer_status do
    case :ets.info(:performance_optimizer) do
      :undefined ->
        %{status: :not_running}
        
      _ ->
        # Get configuration
        case :ets.lookup(:performance_optimizer, :config) do
          [{:config, config}] ->
            # Get cache stats
            caches = :ets.match_object(:performance_optimizations, {{:cache, :_}, :_})
            |> Enum.map(fn {{:cache, name}, info} ->
              {name, %{
                hits: info.hits,
                misses: info.misses,
                hit_ratio: if info.hits + info.misses > 0 do
                  info.hits / (info.hits + info.misses)
                else
                  0.0
                end
              }}
            end)
            |> Map.new()
            
            # Return status info
            %{
              status: :running,
              adaptive_mode: config.adaptive_mode,
              initialized_at: config.initialized_at,
              caches: caches
            }
            
          [] ->
            %{status: :initializing}
        end
    end
  end
end