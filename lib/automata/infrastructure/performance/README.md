# Automata Performance Framework

This directory contains the performance framework for the Automata system, providing comprehensive performance monitoring, optimization, and control capabilities.

## Overview

The performance framework consists of several integrated components:

1. **Metrics Collection**: Capturing and analyzing performance metrics from across the system
2. **Rate Limiting**: Controlling throughput to prevent overload
3. **Benchmarking**: Tools for measuring and comparing performance
4. **Profiling**: Identifying performance bottlenecks
5. **Optimization**: Automatic tuning of system parameters

These components work together to provide a complete performance management solution.

## Key Components

### Metrics Collector

The `MetricsCollector` module provides detailed performance metrics collection:

- Operation latency tracking with histogram distributions
- Throughput measurement
- Resource utilization monitoring
- Custom metric collection
- Support for aggregation at multiple time resolutions

```elixir
# Record operation latency
MetricsCollector.record_latency("database.query", 150_000, %{query_type: "select"})

# Record operation throughput
MetricsCollector.record_throughput("agent.updates", 100, %{agent_type: "behavior_tree"})

# Get performance snapshot
snapshot = MetricsCollector.get_performance_snapshot()
```

### Rate Limiter

The `RateLimiter` module provides multiple rate limiting algorithms:

- Token bucket for smooth traffic with burst handling
- Leaky bucket for strict flow control
- Fixed and sliding windows for time-based limiting
- Distributed rate limiting support

```elixir
# Create a rate limiter
RateLimiter.create("api_requests", :token_bucket, rate: 100, burst: 500)

# Check if an operation is allowed
case RateLimiter.check("api_requests") do
  {:ok, _} -> 
    # Proceed with operation
  {:error, :rate_limited, info} ->
    # Operation would exceed the rate limit
    # info.wait_time_ms contains the suggested wait time
end

# Execute a function with rate limiting
RateLimiter.execute("api_requests", fn ->
  # Rate-limited operation
end)
```

### Benchmarker

The `Benchmarker` module provides tools for measuring and comparing performance:

- Simple benchmarks with statistical analysis
- Load testing for finding system limits
- Implementation comparison
- Concurrency testing

```elixir
# Run a simple benchmark
result = Benchmarker.run("my_operation", fn -> 
  MyModule.perform_operation()
end, iterations: 1000)

# Compare different implementations
comparison = Benchmarker.compare("sorting_algorithms", %{
  "bubble_sort" => fn -> bubble_sort(data) end,
  "merge_sort" => fn -> merge_sort(data) end
})

# Run a load test
load_test = Benchmarker.load_test("api_endpoint", fn ->
  HTTPClient.get("https://api.example.com/endpoint")
end, initial_rate: 10, target_rate: 500)
```

### Profiler

The `Profiler` module provides tools for identifying performance bottlenecks:

- Function profiling with call graphs
- Memory usage analysis
- Process monitoring
- Message queue tracking
- System health monitoring

```elixir
# Profile a function
profile = Profiler.profile_function("critical_function", fn ->
  MyCriticalModule.perform_operation()
end)

# Profile memory usage
memory_profile = Profiler.profile_memory(top_n: 20)

# Monitor process activity
process_profile = Profiler.profile_processes(10_000)

# Monitor message passing
message_profile = Profiler.profile_messages(10_000)
```

### Optimizer

The `Optimizer` module provides automatic performance tuning:

- Process allocation optimization
- Load shedding for high-traffic periods
- Caching for expensive operations
- Adaptive performance tuning

```elixir
# Optimize process allocation
{:ok, opts} = Optimizer.optimize_process_allocation(:io_bound)

# Set up load shedding
Optimizer.setup_load_shedding("database_service", max_load: 0.8)

# Check if should process or shed
if Optimizer.should_process?("database_service") do
  # Process request
else
  # Shed request
end

# Use caching
Optimizer.create_cache("expensive_results")
result = Optimizer.cached("expensive_results", key, fn ->
  # Expensive computation
end)
```

## Integration with Other Systems

The performance framework integrates with other parts of Automata:

- **Telemetry System**: Performance metrics are published as telemetry events
- **Resilience Framework**: Circuit breakers use performance data to prevent cascading failures
- **Distributed Registry**: Components can be monitored across multiple nodes
- **Event Bus**: Performance events are published for system-wide awareness

## Configuration

The performance framework can be configured through the application environment:

```elixir
config :automata, Automata.Infrastructure.Performance,
  # Metrics collection
  metrics_retention_period: :timer.hours(24),
  metrics_collection_interval: 5_000,
  
  # Rate limiting
  default_rate_limit_burst: 1000,
  
  # Optimization
  adaptive_mode: true,
  learning_rate: 0.1,
  tuning_interval: 60_000
```

## Best Practices

1. **Metrics Collection**: Record metrics for all critical operations
2. **Rate Limiting**: Apply rate limits to protect external dependencies and critical resources
3. **Load Testing**: Regularly run load tests to identify system limits
4. **Profiling**: Profile critical paths to identify bottlenecks
5. **Caching**: Cache expensive computations and frequently accessed data
6. **Load Shedding**: Set up load shedding for graceful degradation under high load