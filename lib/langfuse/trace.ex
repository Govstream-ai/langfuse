defmodule Langfuse.Trace do
  @moduledoc """
  Represents a trace in Langfuse.

  A trace is the top-level container for observability data. It groups
  related spans, generations, and events together.

  ## Examples

      trace = Langfuse.Trace.new(name: "chat-completion", user_id: "user-123")

      span = Langfuse.Span.new(trace, name: "retrieval")
      generation = Langfuse.Generation.new(trace, name: "llm-call", model: "gpt-4")

  """

  alias Langfuse.Ingestion

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          user_id: String.t() | nil,
          session_id: String.t() | nil,
          metadata: map() | nil,
          tags: list(String.t()) | nil,
          public: boolean() | nil,
          input: term() | nil,
          output: term() | nil,
          timestamp: DateTime.t()
        }

  @enforce_keys [:id, :name, :timestamp]
  defstruct [
    :id,
    :name,
    :user_id,
    :session_id,
    :metadata,
    :tags,
    :public,
    :input,
    :output,
    :timestamp
  ]

  @spec new(keyword()) :: t()
  def new(opts) do
    name = Keyword.fetch!(opts, :name)

    trace = %__MODULE__{
      id: opts[:id] || generate_id(),
      name: name,
      user_id: opts[:user_id],
      session_id: opts[:session_id],
      metadata: opts[:metadata],
      tags: opts[:tags],
      public: opts[:public],
      input: opts[:input],
      output: opts[:output],
      timestamp: opts[:timestamp] || DateTime.utc_now()
    }

    enqueue_event(trace, :create)
    trace
  end

  @spec update(t(), keyword()) :: t()
  def update(%__MODULE__{} = trace, opts) do
    updated =
      trace
      |> maybe_update(:name, opts)
      |> maybe_update(:user_id, opts)
      |> maybe_update(:session_id, opts)
      |> maybe_update(:metadata, opts)
      |> maybe_update(:tags, opts)
      |> maybe_update(:public, opts)
      |> maybe_update(:input, opts)
      |> maybe_update(:output, opts)

    enqueue_event(updated, :update)
    updated
  end

  @spec get_id(t()) :: String.t()
  def get_id(%__MODULE__{id: id}), do: id

  @spec get_session_id(t()) :: String.t() | nil
  def get_session_id(%__MODULE__{session_id: session_id}), do: session_id

  defp enqueue_event(trace, type) do
    event = %{
      id: generate_id(),
      type: event_type(type),
      timestamp: DateTime.to_iso8601(DateTime.utc_now()),
      body: to_body(trace)
    }

    Ingestion.enqueue(event)
  end

  defp event_type(:create), do: "trace-create"
  defp event_type(:update), do: "trace-create"

  defp to_body(trace) do
    %{
      id: trace.id,
      name: trace.name,
      timestamp: DateTime.to_iso8601(trace.timestamp)
    }
    |> maybe_put(:userId, trace.user_id)
    |> maybe_put(:sessionId, trace.session_id)
    |> maybe_put(:metadata, trace.metadata)
    |> maybe_put(:tags, trace.tags)
    |> maybe_put(:public, trace.public)
    |> maybe_put(:input, trace.input)
    |> maybe_put(:output, trace.output)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp maybe_update(trace, key, opts) do
    case Keyword.get(opts, key) do
      nil -> trace
      value -> Map.put(trace, key, value)
    end
  end

  defp generate_id do
    Base.encode16(:crypto.strong_rand_bytes(12), case: :lower)
  end
end
