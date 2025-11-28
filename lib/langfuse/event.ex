defmodule Langfuse.Event do
  @moduledoc """
  Represents an event observation in Langfuse.

  Events are point-in-time occurrences within a trace, useful for
  logging specific moments like user actions, errors, or milestones.

  ## Examples

      trace = Langfuse.trace(name: "user-session")

      Langfuse.event(trace,
        name: "button-click",
        input: %{button_id: "submit"},
        metadata: %{page: "/checkout"}
      )

  """

  alias Langfuse.{Ingestion, Trace, Span}

  @type level :: :debug | :default | :warning | :error
  @type parent :: Trace.t() | Span.t()

  @type t :: %__MODULE__{
          id: String.t(),
          trace_id: String.t(),
          parent_observation_id: String.t() | nil,
          name: String.t(),
          start_time: DateTime.t(),
          input: term() | nil,
          output: term() | nil,
          metadata: map() | nil,
          level: level() | nil,
          status_message: String.t() | nil
        }

  @enforce_keys [:id, :trace_id, :name, :start_time]
  defstruct [
    :id,
    :trace_id,
    :parent_observation_id,
    :name,
    :start_time,
    :input,
    :output,
    :metadata,
    :level,
    :status_message
  ]

  @spec new(parent(), keyword()) :: t()
  def new(parent, opts) do
    name = Keyword.fetch!(opts, :name)
    {trace_id, parent_observation_id} = extract_parent_ids(parent)

    event = %__MODULE__{
      id: opts[:id] || generate_id(),
      trace_id: trace_id,
      parent_observation_id: parent_observation_id,
      name: name,
      start_time: opts[:start_time] || DateTime.utc_now(),
      input: opts[:input],
      output: opts[:output],
      metadata: opts[:metadata],
      level: opts[:level],
      status_message: opts[:status_message]
    }

    enqueue_event(event)
    event
  end

  @spec get_id(t()) :: String.t()
  def get_id(%__MODULE__{id: id}), do: id

  @spec get_trace_id(t()) :: String.t()
  def get_trace_id(%__MODULE__{trace_id: trace_id}), do: trace_id

  defp extract_parent_ids(%Trace{id: trace_id}), do: {trace_id, nil}
  defp extract_parent_ids(%Span{trace_id: trace_id, id: id}), do: {trace_id, id}

  defp enqueue_event(event) do
    ingestion_event = %{
      id: generate_id(),
      type: "event-create",
      timestamp: DateTime.to_iso8601(DateTime.utc_now()),
      body: to_body(event)
    }

    Ingestion.enqueue(ingestion_event)
  end

  defp to_body(event) do
    %{
      id: event.id,
      traceId: event.trace_id,
      name: event.name,
      startTime: DateTime.to_iso8601(event.start_time)
    }
    |> maybe_put(:parentObservationId, event.parent_observation_id)
    |> maybe_put(:input, event.input)
    |> maybe_put(:output, event.output)
    |> maybe_put(:metadata, event.metadata)
    |> maybe_put(:level, event.level && level_to_string(event.level))
    |> maybe_put(:statusMessage, event.status_message)
  end

  defp level_to_string(:debug), do: "DEBUG"
  defp level_to_string(:default), do: "DEFAULT"
  defp level_to_string(:warning), do: "WARNING"
  defp level_to_string(:error), do: "ERROR"

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp generate_id do
    Base.encode16(:crypto.strong_rand_bytes(12), case: :lower)
  end
end
