defmodule Langfuse.Generation do
  @moduledoc """
  Represents a generation (LLM call) observation in Langfuse.

  Generations track LLM API calls including model, input/output,
  token usage, and model parameters.

  ## Examples

      trace = Langfuse.trace(name: "chat")

      generation = Langfuse.generation(trace,
        name: "chat-completion",
        model: "gpt-4",
        input: [%{role: "user", content: "Hello"}],
        model_parameters: %{temperature: 0.7}
      )

      # After receiving response
      generation = Langfuse.update(generation,
        output: %{role: "assistant", content: "Hi there!"},
        usage: %{input: 10, output: 5, total: 15}
      )

      generation = Langfuse.end_observation(generation)

  """

  alias Langfuse.{Ingestion, Trace, Span}

  @type level :: :debug | :default | :warning | :error
  @type parent :: Trace.t() | Span.t() | t()

  @type usage :: %{
          optional(:input) => non_neg_integer(),
          optional(:output) => non_neg_integer(),
          optional(:total) => non_neg_integer(),
          optional(:unit) => String.t(),
          optional(:input_cost) => float(),
          optional(:output_cost) => float(),
          optional(:total_cost) => float()
        }

  @type t :: %__MODULE__{
          id: String.t(),
          trace_id: String.t(),
          parent_observation_id: String.t() | nil,
          name: String.t(),
          model: String.t() | nil,
          model_parameters: map() | nil,
          start_time: DateTime.t(),
          end_time: DateTime.t() | nil,
          completion_start_time: DateTime.t() | nil,
          input: term() | nil,
          output: term() | nil,
          usage: usage() | nil,
          metadata: map() | nil,
          level: level() | nil,
          status_message: String.t() | nil,
          prompt_name: String.t() | nil,
          prompt_version: pos_integer() | nil
        }

  @enforce_keys [:id, :trace_id, :name, :start_time]
  defstruct [
    :id,
    :trace_id,
    :parent_observation_id,
    :name,
    :model,
    :model_parameters,
    :start_time,
    :end_time,
    :completion_start_time,
    :input,
    :output,
    :usage,
    :metadata,
    :level,
    :status_message,
    :prompt_name,
    :prompt_version
  ]

  @spec new(parent(), keyword()) :: t()
  def new(parent, opts) do
    name = Keyword.fetch!(opts, :name)
    {trace_id, parent_observation_id} = extract_parent_ids(parent)

    generation = %__MODULE__{
      id: opts[:id] || generate_id(),
      trace_id: trace_id,
      parent_observation_id: parent_observation_id,
      name: name,
      model: opts[:model],
      model_parameters: opts[:model_parameters],
      start_time: opts[:start_time] || DateTime.utc_now(),
      end_time: opts[:end_time],
      completion_start_time: opts[:completion_start_time],
      input: opts[:input],
      output: opts[:output],
      usage: opts[:usage],
      metadata: opts[:metadata],
      level: opts[:level],
      status_message: opts[:status_message],
      prompt_name: opts[:prompt_name],
      prompt_version: opts[:prompt_version]
    }

    enqueue_event(generation, :create)
    generation
  end

  @spec update(t(), keyword()) :: t()
  def update(%__MODULE__{} = generation, opts) do
    updated =
      generation
      |> maybe_update(:name, opts)
      |> maybe_update(:model, opts)
      |> maybe_update(:model_parameters, opts)
      |> maybe_update(:end_time, opts)
      |> maybe_update(:completion_start_time, opts)
      |> maybe_update(:input, opts)
      |> maybe_update(:output, opts)
      |> maybe_update(:usage, opts)
      |> maybe_update(:metadata, opts)
      |> maybe_update(:level, opts)
      |> maybe_update(:status_message, opts)

    enqueue_event(updated, :update)
    updated
  end

  @spec end_generation(t()) :: t()
  def end_generation(%__MODULE__{} = generation) do
    update(generation, end_time: DateTime.utc_now())
  end

  @spec get_id(t()) :: String.t()
  def get_id(%__MODULE__{id: id}), do: id

  @spec get_trace_id(t()) :: String.t()
  def get_trace_id(%__MODULE__{trace_id: trace_id}), do: trace_id

  defp extract_parent_ids(%Trace{id: trace_id}), do: {trace_id, nil}
  defp extract_parent_ids(%Span{trace_id: trace_id, id: id}), do: {trace_id, id}
  defp extract_parent_ids(%__MODULE__{trace_id: trace_id, id: id}), do: {trace_id, id}

  defp enqueue_event(generation, type) do
    event = %{
      id: generate_id(),
      type: event_type(type),
      timestamp: DateTime.to_iso8601(DateTime.utc_now()),
      body: to_body(generation)
    }

    Ingestion.enqueue(event)
  end

  defp event_type(:create), do: "generation-create"
  defp event_type(:update), do: "generation-update"

  defp to_body(gen) do
    %{
      id: gen.id,
      traceId: gen.trace_id,
      name: gen.name,
      startTime: DateTime.to_iso8601(gen.start_time)
    }
    |> maybe_put(:parentObservationId, gen.parent_observation_id)
    |> maybe_put(:model, gen.model)
    |> maybe_put(:modelParameters, gen.model_parameters)
    |> maybe_put(:endTime, gen.end_time && DateTime.to_iso8601(gen.end_time))
    |> maybe_put(:completionStartTime, gen.completion_start_time && DateTime.to_iso8601(gen.completion_start_time))
    |> maybe_put(:input, gen.input)
    |> maybe_put(:output, gen.output)
    |> maybe_put(:usage, format_usage(gen.usage))
    |> maybe_put(:metadata, gen.metadata)
    |> maybe_put(:level, gen.level && level_to_string(gen.level))
    |> maybe_put(:statusMessage, gen.status_message)
    |> maybe_put(:promptName, gen.prompt_name)
    |> maybe_put(:promptVersion, gen.prompt_version)
  end

  defp format_usage(nil), do: nil

  defp format_usage(usage) do
    %{}
    |> maybe_put(:input, usage[:input])
    |> maybe_put(:output, usage[:output])
    |> maybe_put(:total, usage[:total])
    |> maybe_put(:unit, usage[:unit])
    |> maybe_put(:inputCost, usage[:input_cost])
    |> maybe_put(:outputCost, usage[:output_cost])
    |> maybe_put(:totalCost, usage[:total_cost])
  end

  defp level_to_string(:debug), do: "DEBUG"
  defp level_to_string(:default), do: "DEFAULT"
  defp level_to_string(:warning), do: "WARNING"
  defp level_to_string(:error), do: "ERROR"

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, _key, map_val) when map_val == %{}, do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp maybe_update(gen, key, opts) do
    case Keyword.get(opts, key) do
      nil -> gen
      value -> Map.put(gen, key, value)
    end
  end

  defp generate_id do
    Base.encode16(:crypto.strong_rand_bytes(12), case: :lower)
  end
end
