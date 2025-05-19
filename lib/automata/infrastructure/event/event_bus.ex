defmodule Automata.Infrastructure.Event.EventBus do
  @moduledoc """
  An event bus for distributed communication between components.
  
  This module provides functionality for:
  - Publishing events to subscribers
  - Subscribing to events by type or pattern
  - Buffering events when subscribers are overloaded
  - Providing delivery guarantees for critical events
  """
  
  use GenServer
  require Logger
  
  defmodule Stats do
    @moduledoc "Statistics tracking for event bus"
    defstruct published: 0,
              delivered: 0,
              dropped: 0,
              buffered: 0,
              by_type: %{}
  end
  
  # Client API
  
  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end
  
  @doc """
  Publishes an event to the event bus.
  
  Events are structured as:
  ```
  %{
    type: :event_type,           # Required
    payload: any(),              # Required 
    metadata: %{                 # Optional
      timestamp: timestamp,      # When the event occurred
      source: source,            # Who generated the event
      correlation_id: id,        # For tracking related events
      ...
    }
  }
  ```
  
  Options:
  - priority: :high, :normal, or :low (default: :normal)
  - delivery: :best_effort or :at_least_once (default: :best_effort)
  - buffer: true or false (default: true)
  """
  def publish(event, opts \\ []) do
    GenServer.cast(__MODULE__, {:publish, event, opts})
  end
  
  @doc """
  Subscribes to events matching the given pattern.
  
  The pattern can be:
  - :all - All events
  - event_type - A specific event type
  - {:prefix, prefix} - Events with types starting with the given prefix
  - function/1 - A function that takes an event and returns true/false
  
  Options:
  - max_buffer: maximum number of events to buffer (default: 1000)
  - buffer_strategy: :drop_oldest or :drop_newest (default: :drop_oldest)
  - ack_required: whether confirmation is required (default: false)
  """
  def subscribe(pattern, opts \\ []) do
    GenServer.call(__MODULE__, {:subscribe, self(), pattern, opts})
  end
  
  @doc """
  Acknowledges receipt of an event.
  
  This is required when subscribing with ack_required: true.
  """
  def acknowledge(event_id) do
    GenServer.cast(__MODULE__, {:acknowledge, self(), event_id})
  end
  
  @doc """
  Gets statistics about event bus usage.
  """
  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end
  
  @doc """
  Clears all subscription buffers.
  """
  def clear_buffers do
    GenServer.call(__MODULE__, :clear_buffers)
  end
  
  # Server callbacks
  
  @impl true
  def init(_init_arg) do
    Logger.info("Starting Event Bus")
    
    # Initialize state
    state = %{
      subscriptions: %{},  # pid => %{pattern: pattern, opts: opts, buffer: buffer}
      pending: %{},        # event_id => %{event: event, recipients: [pid], opts: opts}
      stats: %Stats{},
      last_event_id: 0
    }
    
    # Start periodic buffer processor
    Process.send_after(self(), :process_buffers, 1000)
    
    {:ok, state}
  end
  
  @impl true
  def handle_cast({:publish, raw_event, opts}, state) do
    # Generate event ID and normalize event
    event_id = state.last_event_id + 1
    timestamp = System.system_time(:millisecond)
    
    metadata = Map.get(raw_event, :metadata, %{})
    metadata = Map.put(metadata, :timestamp, timestamp)
    metadata = Map.put(metadata, :event_id, event_id)
    
    event = %{
      type: raw_event.type,
      payload: raw_event.payload,
      metadata: metadata
    }
    
    # Find matching subscribers
    recipients = find_matching_subscribers(event, state.subscriptions)
    
    # Update statistics
    stats = update_publish_stats(state.stats, event.type)
    
    # Handle event based on delivery guarantees
    new_state = case Keyword.get(opts, :delivery, :best_effort) do
      :at_least_once ->
        # Track event for acknowledgement
        pending = Map.put(state.pending, event_id, %{
          event: event,
          recipients: recipients,
          opts: opts,
          published_at: timestamp
        })
        
        # Deliver to subscribers
        deliver_event(event, recipients, state.subscriptions, opts)
        
        %{state | 
          pending: pending, 
          stats: stats,
          last_event_id: event_id
        }
        
      :best_effort ->
        # Deliver without tracking
        deliver_event(event, recipients, state.subscriptions, opts)
        
        %{state | 
          stats: stats,
          last_event_id: event_id
        }
    end
    
    {:noreply, new_state}
  end
  
  @impl true
  def handle_cast({:acknowledge, subscriber, event_id}, state) do
    case Map.fetch(state.pending, event_id) do
      {:ok, %{recipients: recipients} = pending_event} ->
        # Remove subscriber from pending recipients
        updated_recipients = recipients -- [subscriber]
        
        # Update or remove pending event
        new_pending = if Enum.empty?(updated_recipients) do
          Map.delete(state.pending, event_id)
        else
          Map.put(state.pending, event_id, %{pending_event | recipients: updated_recipients})
        end
        
        # Update stats
        stats = %{state.stats | delivered: state.stats.delivered + 1}
        
        {:noreply, %{state | pending: new_pending, stats: stats}}
        
      :error ->
        # Event not found, ignore
        {:noreply, state}
    end
  end
  
  @impl true
  def handle_call({:subscribe, subscriber, pattern, opts}, _from, state) do
    # Store subscription
    subscription = %{
      pattern: pattern,
      opts: opts,
      buffer: [],
      last_delivery: System.system_time(:millisecond)
    }
    
    # Monitor subscriber
    Process.monitor(subscriber)
    
    subscriptions = Map.put(state.subscriptions, subscriber, subscription)
    
    {:reply, :ok, %{state | subscriptions: subscriptions}}
  end
  
  @impl true
  def handle_call(:get_stats, _from, state) do
    # Add buffer sizes to stats
    buffer_sizes = Enum.map(state.subscriptions, fn {_subscriber, %{buffer: buffer}} ->
      length(buffer)
    end)
    
    total_buffered = Enum.sum(buffer_sizes)
    stats = %{state.stats | buffered: total_buffered}
    
    {:reply, stats, %{state | stats: stats}}
  end
  
  @impl true
  def handle_call(:clear_buffers, _from, state) do
    # Clear all buffers
    subscriptions = Enum.map(state.subscriptions, fn {subscriber, subscription} ->
      {subscriber, %{subscription | buffer: []}}
    end) |> Map.new()
    
    stats = %{state.stats | buffered: 0}
    
    {:reply, :ok, %{state | subscriptions: subscriptions, stats: stats}}
  end
  
  @impl true
  def handle_info(:process_buffers, state) do
    # Process buffers for each subscriber
    {subscriptions, stats} = Enum.reduce(
      state.subscriptions,
      {state.subscriptions, state.stats},
      fn {subscriber, subscription}, {subs_acc, stats_acc} ->
        {updated_subscription, updated_stats} = process_buffer(
          subscriber, 
          subscription, 
          stats_acc
        )
        
        {Map.put(subs_acc, subscriber, updated_subscription), updated_stats}
      end
    )
    
    # Schedule next buffer processing
    Process.send_after(self(), :process_buffers, 1000)
    
    {:noreply, %{state | subscriptions: subscriptions, stats: stats}}
  end
  
  @impl true
  def handle_info({:DOWN, _ref, :process, subscriber, _reason}, state) do
    # Subscriber died, remove subscription
    subscriptions = Map.delete(state.subscriptions, subscriber)
    
    # Remove from pending events
    pending = Enum.map(state.pending, fn {event_id, event} ->
      updated_recipients = event.recipients -- [subscriber]
      
      if Enum.empty?(updated_recipients) do
        nil  # Mark for removal
      else
        {event_id, %{event | recipients: updated_recipients}}
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Map.new()
    
    {:noreply, %{state | subscriptions: subscriptions, pending: pending}}
  end
  
  @impl true
  def handle_info({:retry_pending, _timeout}, state) do
    now = System.system_time(:millisecond)
    
    # Find events to retry (older than 5 seconds)
    {to_retry, still_pending} = Enum.split_with(
      state.pending,
      fn {_id, event} -> now - event.published_at > 5000 end
    )
    
    # Retry events
    Enum.each(to_retry, fn {_id, event} ->
      deliver_event(event.event, event.recipients, state.subscriptions, event.opts)
    end)
    
    # Schedule next retry if needed
    if map_size(still_pending) > 0 do
      Process.send_after(self(), {:retry_pending, 5000}, 5000)
    end
    
    {:noreply, state}
  end
  
  # Private functions
  
  defp find_matching_subscribers(event, subscriptions) do
    Enum.filter(subscriptions, fn {_subscriber, subscription} ->
      matches_pattern?(event, subscription.pattern)
    end)
    |> Enum.map(fn {subscriber, _} -> subscriber end)
  end
  
  defp matches_pattern?(event, :all), do: true
  
  defp matches_pattern?(event, pattern) when is_atom(pattern) do
    event.type == pattern
  end
  
  defp matches_pattern?(event, {:prefix, prefix}) do
    event_type = to_string(event.type)
    String.starts_with?(event_type, to_string(prefix))
  end
  
  defp matches_pattern?(event, pattern) when is_function(pattern, 1) do
    pattern.(event)
  end
  
  defp matches_pattern?(_event, _pattern), do: false
  
  defp deliver_event(event, recipients, subscriptions, opts) do
    priority = Keyword.get(opts, :priority, :normal)
    buffer_enabled = Keyword.get(opts, :buffer, true)
    
    Enum.each(recipients, fn subscriber ->
      subscription = Map.get(subscriptions, subscriber)
      
      if subscription do
        max_buffer = Keyword.get(
          subscription.opts, 
          :max_buffer, 
          1000
        )
        
        # Check if subscriber's mailbox is full
        message_queue_len = Process.info(subscriber, :message_queue_len)
        
        cond do
          # Mailbox is overloaded, buffer if enabled
          is_tuple(message_queue_len) and 
          elem(message_queue_len, 1) > 100 and 
          buffer_enabled ->
            buffer_event(subscriber, event, subscription, max_buffer)
            
          # Direct delivery
          true ->
            send(subscriber, {:event, event})
        end
      end
    end)
  end
  
  defp buffer_event(subscriber, event, subscription, max_buffer) do
    buffer = subscription.buffer
    
    updated_buffer = if length(buffer) >= max_buffer do
      # Buffer full, drop based on strategy
      case Keyword.get(subscription.opts, :buffer_strategy, :drop_oldest) do
        :drop_oldest -> Enum.drop(buffer, 1) ++ [event]
        :drop_newest -> buffer
      end
    else
      buffer ++ [event]
    end
    
    # Update subscription with new buffer
    updated_subscription = %{subscription | buffer: updated_buffer}
    GenServer.call(__MODULE__, {:update_subscription, subscriber, updated_subscription})
  end
  
  defp process_buffer(subscriber, subscription, stats) do
    buffer = subscription.buffer
    
    # Deliver up to 10 buffered events
    {to_deliver, remaining} = Enum.split(buffer, 10)
    
    Enum.each(to_deliver, fn event ->
      send(subscriber, {:event, event})
    end)
    
    # Update stats
    delivered_count = length(to_deliver)
    updated_stats = %{stats | 
      delivered: stats.delivered + delivered_count,
      buffered: stats.buffered - delivered_count
    }
    
    updated_subscription = %{subscription | 
      buffer: remaining,
      last_delivery: System.system_time(:millisecond)
    }
    
    {updated_subscription, updated_stats}
  end
  
  defp update_publish_stats(stats, event_type) do
    # Update total count
    stats = %{stats | published: stats.published + 1}
    
    # Update by type
    by_type = Map.update(
      stats.by_type,
      event_type,
      1,
      &(&1 + 1)
    )
    
    %{stats | by_type: by_type}
  end
end