defmodule Langfuse.Span do
  @moduledoc """
  Represents a span observation in Langfuse.

  Spans are used to track operations within a trace, such as
  retrieval steps, preprocessing, or other logical units of work.

  ## Examples

      trace = Langfuse.trace(name: "rag-pipeline")

      span = Langfuse.span(trace, name: "document-retrieval")
      # ... do work ...
      span = Langfuse.update(span, output: retrieved_docs)
      span = Langfuse.end_observation(span)

  """

  alias Langfuse.{Ingestion, Trace}

  @type level :: :debug | :default | :warning | :error
  @type parent :: Trace.t() | t()

  @type t :: %__MODULE__{
          id: String.t(),
          trace_id: String.t(),
          parent_observation_id: String.t() | nil,
          name: String.t(),
          start_time: DateTime.t(),
          end_time: DateTime.t() | nil,
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
    :end_time,
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

    span = %__MODULE__{
      id: opts[:id] || generate_id(),
      trace_id: trace_id,
      parent_observation_id: parent_observation_id,
      name: name,
      start_time: opts[:start_time] || DateTime.utc_now(),
      end_time: opts[:end_time],
      input: opts[:input],
      output: opts[:output],
      metadata: opts[:metadata],
      level: opts[:level],
      status_message: opts[:status_message]
    }

    enqueue_event(span, :create)
    span
  end

  @spec update(t(), keyword()) :: t()
  def update(%__MODULE__{} = span, opts) do
    updated =
      span
      |> maybe_update(:name, opts)
      |> maybe_update(:end_time, opts)
      |> maybe_update(:input, opts)
      |> maybe_update(:output, opts)
      |> maybe_update(:metadata, opts)
      |> maybe_update(:level, opts)
      |> maybe_update(:status_message, opts)

    enqueue_event(updated, :update)
    updated
  end

  @spec end_span(t()) :: t()
  def end_span(%__MODULE__{} = span) do
    update(span, end_time: DateTime.utc_now())
  end

  @spec get_id(t()) :: String.t()
  def get_id(%__MODULE__{id: id}), do: id

  @spec get_trace_id(t()) :: String.t()
  def get_trace_id(%__MODULE__{trace_id: trace_id}), do: trace_id

  defp extract_parent_ids(%Trace{id: trace_id}), do: {trace_id, nil}
  defp extract_parent_ids(%__MODULE__{trace_id: trace_id, id: id}), do: {trace_id, id}

  defp enqueue_event(span, type) do
    event = %{
      id: generate_id(),
      type: event_type(type),
      timestamp: DateTime.to_iso8601(DateTime.utc_now()),
      body: to_body(span)
    }

    Ingestion.enqueue(event)
  end

  defp event_type(:create), do: "span-create"
  defp event_type(:update), do: "span-update"

  defp to_body(span) do
    %{
      id: span.id,
      traceId: span.trace_id,
      name: span.name,
      startTime: DateTime.to_iso8601(span.start_time)
    }
    |> maybe_put(:parentObservationId, span.parent_observation_id)
    |> maybe_put(:endTime, span.end_time && DateTime.to_iso8601(span.end_time))
    |> maybe_put(:input, span.input)
    |> maybe_put(:output, span.output)
    |> maybe_put(:metadata, span.metadata)
    |> maybe_put(:level, span.level && level_to_string(span.level))
    |> maybe_put(:statusMessage, span.status_message)
  end

  defp level_to_string(:debug), do: "DEBUG"
  defp level_to_string(:default), do: "DEFAULT"
  defp level_to_string(:warning), do: "WARNING"
  defp level_to_string(:error), do: "ERROR"

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp maybe_update(span, key, opts) do
    case Keyword.get(opts, key) do
      nil -> span
      value -> Map.put(span, key, value)
    end
  end

  defp generate_id do
    Base.encode16(:crypto.strong_rand_bytes(12), case: :lower)
  end
end
