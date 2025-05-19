# Automata Resilience Framework

This directory contains the resilience framework for the Automata system, which provides comprehensive error handling, logging, monitoring, and recovery capabilities to ensure reliability and stability.

## Overview

The resilience framework is composed of several key components:

1. **Error Handling**: Standardized error formats, propagation, tracking, and reporting
2. **Circuit Breakers**: Prevent cascading failures by isolating problematic dependencies
3. **Enhanced Logging**: Structured logging with context, correlation, and integration with telemetry
4. **Telemetry**: Metrics collection, aggregation, and reporting for system insights
5. **Health Monitoring**: System-wide health checks, status tracking, and graceful degradation

These components work together to create a robust foundation for building reliable distributed systems.

## Key Components

### Error Module

The `Error` module provides a standardized way to create, wrap, and handle errors throughout the system:

- Consistent error format with type, message, metadata, and stacktrace
- Error wrapping to maintain context across boundaries
- Integration with logging system
- Tracking for error analysis

### Circuit Breaker

The `CircuitBreaker` implements the circuit breaker pattern to prevent cascading failures:

- Tracks failures in dependent components
- Opens the circuit when failure thresholds are exceeded
- Prevents further calls to failing dependencies
- Periodically tests if the dependency has recovered
- Provides statistics and monitoring

### Enhanced Logger

The `Logger` module enhances the standard Elixir Logger with:

- Structured logging with standardized metadata
- Context propagation across process boundaries
- Correlation IDs for request tracing
- Performance measurement and monitoring
- Integration with telemetry for metrics

### Telemetry System

The `Telemetry` module provides:

- Standardized event emission
- Automatic metrics collection
- Spans for operation tracing
- Integration with logging and health monitoring

### Health Monitoring

The `Health` module provides:

- Periodic health checks for system components
- Aggregated system health status
- Component-level health tracking
- Integration with telemetry for metrics

## Usage Examples

See the `Automata.Examples.ResilienceDemo` module for comprehensive usage examples of all resilience features.

### Basic Error Handling

```elixir
# Create a standard error
error = Error.new(:validation_error, "Invalid input", %{field: "email"})

# Log the error
Error.log(error)

# Wrap an error from an external API
with {:error, reason} <- external_api_call() do
  Error.wrap({:error, reason}, %{context: "user_service"})
end
```

### Circuit Breaker

```elixir
# Create a circuit breaker
CircuitBreakerSupervisor.create(name: "database")

# Execute operation with circuit breaker protection
CircuitBreaker.execute("database", fn ->
  Database.query("SELECT * FROM users")
end)
```

### Enhanced Logging

```elixir
# Simple logging
Logger.info("Processing request")

# Structured logging with metadata
Logger.info("User created", %{user_id: "123", email: "user@example.com"})

# Logging with correlation
Logger.with_correlation(fn ->
  Logger.info("Starting operation")
  # ... perform operation
  Logger.info("Operation completed")
end).()

# Measure operation timing
Logger.measure("database_query", fn ->
  Database.query("SELECT * FROM users")
end)
```

### Telemetry

```elixir
# Execute a telemetry event
Telemetry.execute([:automata, :http, :request], %{duration: 120}, %{path: "/api/users"})

# Use a span to trace an operation
Telemetry.span("process_user", fn ->
  # ... process user
  {:ok, user}
end)
```

### Health Monitoring

```elixir
# Register a health check
Health.register_check(
  fn -> check_database_connectivity() end,
  id: "database",
  interval: 30_000
)

# Get system health
Health.get_system_health()

# Set component health manually
Health.set_component_health(:auth_service, :degraded, "High latency detected")
```

## Integration with Other Components

The resilience framework integrates with other infrastructure components:

- **Distributed Registry**: For process discovery and management
- **Event Bus**: For event-driven communication
- **Configuration**: For centralized configuration management
- **Blackboard**: For shared state management

## Configuration

The behavior of the resilience framework can be configured through the application's configuration:

```elixir
config :automata, Automata.Infrastructure.Resilience,
  error_tracking_limit: 1000,
  circuit_breaker_defaults: [
    failure_threshold: 5,
    retry_timeout: 30_000,
    reset_timeout: 60_000
  ],
  telemetry_reporting_interval: 60_000
```

## Best Practices

1. **Standardize Error Handling**: Always use the `Error` module for consistent error handling.
2. **Circuit Breakers for External Dependencies**: Use circuit breakers for all external service calls.
3. **Structured Logging**: Include relevant context in log messages using metadata.
4. **Correlation IDs**: Use correlation IDs to track requests across multiple services.
5. **Health Checks**: Implement health checks for all critical system components.
6. **Telemetry for Insights**: Use telemetry events to gather insights about system behavior.