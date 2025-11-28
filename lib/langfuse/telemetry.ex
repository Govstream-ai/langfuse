defmodule Langfuse.Telemetry do
  @moduledoc """
  Telemetry events emitted by the Langfuse SDK.

  ## Events

  ### HTTP Events

  * `[:langfuse, :http, :request, :start]` - Emitted when an HTTP request starts
    * Measurements: `%{system_time: integer}`
    * Metadata: `%{method: atom, path: String.t, host: String.t}`

  * `[:langfuse, :http, :request, :stop]` - Emitted when an HTTP request completes
    * Measurements: `%{duration: integer}` (native time units)
    * Metadata: `%{method: atom, path: String.t, host: String.t, result: :ok | :error}`

  ### Ingestion Events

  * `[:langfuse, :ingestion, :flush, :start]` - Emitted when a batch flush starts
    * Measurements: `%{batch_size: integer}`
    * Metadata: `%{}`

  * `[:langfuse, :ingestion, :flush, :stop]` - Emitted when a batch flush completes
    * Measurements: `%{batch_size: integer, success_count: integer, error_count: integer}`
    * Metadata: `%{}`

  * `[:langfuse, :ingestion, :flush, :error]` - Emitted when a batch flush fails
    * Measurements: `%{batch_size: integer}`
    * Metadata: `%{reason: term}`

  ### Prompt Events

  * `[:langfuse, :prompt, :fetch, :start]` - Emitted when fetching a prompt
    * Measurements: `%{system_time: integer}`
    * Metadata: `%{name: String.t, version: integer | nil, label: String.t | nil}`

  * `[:langfuse, :prompt, :fetch, :stop]` - Emitted when prompt fetch completes
    * Measurements: `%{duration: integer}`
    * Metadata: `%{name: String.t, result: :ok | :error | :cache_hit}`

  ## Example Usage

      :telemetry.attach(
        "langfuse-logger",
        [:langfuse, :http, :request, :stop],
        fn event, measurements, metadata, _config ->
          duration_ms = System.convert_time_unit(measurements.duration, :native, :millisecond)
          Logger.info("Langfuse HTTP \#{metadata.method} \#{metadata.path} took \#{duration_ms}ms")
        end,
        nil
      )

  """

  @doc """
  Returns a list of all telemetry event names emitted by this library.
  """
  @spec events() :: list(list(atom()))
  def events do
    [
      [:langfuse, :http, :request, :start],
      [:langfuse, :http, :request, :stop],
      [:langfuse, :ingestion, :flush, :start],
      [:langfuse, :ingestion, :flush, :stop],
      [:langfuse, :ingestion, :flush, :error],
      [:langfuse, :prompt, :fetch, :start],
      [:langfuse, :prompt, :fetch, :stop]
    ]
  end

  @doc """
  Attaches a default logger handler for Langfuse telemetry events.

  Useful for debugging. Logs all events at debug level.

  ## Options

    * `:level` - Log level (default: `:debug`)

  """
  @spec attach_default_logger(keyword()) :: :ok | {:error, :already_exists}
  def attach_default_logger(opts \\ []) do
    level = Keyword.get(opts, :level, :debug)

    :telemetry.attach_many(
      "langfuse-default-logger",
      events(),
      &log_event/4,
      %{level: level}
    )
  end

  @doc """
  Detaches the default logger handler.
  """
  @spec detach_default_logger() :: :ok | {:error, :not_found}
  def detach_default_logger do
    :telemetry.detach("langfuse-default-logger")
  end

  defp log_event(event, measurements, metadata, %{level: level}) do
    require Logger
    event_name = Enum.join(event, ".")
    Logger.log(level, "[Langfuse] #{event_name} #{inspect(measurements)} #{inspect(metadata)}")
  end
end
