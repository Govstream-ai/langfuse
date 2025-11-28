defmodule Langfuse.OpenTelemetry.TraceContext do
  @moduledoc """
  W3C Trace Context support for distributed tracing.

  This module implements the [W3C Trace Context](https://www.w3.org/TR/trace-context/)
  specification for propagating trace correlation across service boundaries.

  ## Trace Context Headers

  The W3C Trace Context uses two HTTP headers:

    * `traceparent` - Required. Contains trace-id, parent-id, and trace-flags
    * `tracestate` - Optional. Vendor-specific trace data

  ## Traceparent Format

  The traceparent header follows this format:

      {version}-{trace-id}-{parent-id}-{trace-flags}
      00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01

  Where:
    * `version` - 2 hex digits (currently `00`)
    * `trace-id` - 32 hex digits (16 bytes)
    * `parent-id` - 16 hex digits (8 bytes)
    * `trace-flags` - 2 hex digits (sampled = `01`)

  ## Usage

  Extract trace context from incoming HTTP headers:

      context = Langfuse.OpenTelemetry.TraceContext.extract(conn.req_headers)

      {:ok, trace} = Langfuse.trace(
        id: context.trace_id,
        name: "incoming-request",
        metadata: %{parent_span_id: context.parent_id}
      )

  Inject trace context into outgoing HTTP requests:

      headers = Langfuse.OpenTelemetry.TraceContext.inject(trace.id, span.id)
      Req.get(url, headers: headers)

  """

  @traceparent_regex ~r/^00-([a-f0-9]{32})-([a-f0-9]{16})-([a-f0-9]{2})$/

  @typedoc "Parsed trace context."
  @type t :: %{
          trace_id: String.t(),
          parent_id: String.t(),
          trace_flags: integer(),
          sampled: boolean(),
          tracestate: String.t() | nil
        }

  @doc """
  Extracts W3C Trace Context from HTTP headers.

  Parses the `traceparent` and optional `tracestate` headers to extract
  trace correlation information.

  ## Examples

      iex> headers = [{"traceparent", "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01"}]
      iex> Langfuse.OpenTelemetry.TraceContext.extract(headers)
      {:ok, %{
        trace_id: "0af7651916cd43dd8448eb211c80319c",
        parent_id: "b7ad6b7169203331",
        trace_flags: 1,
        sampled: true,
        tracestate: nil
      }}

      iex> Langfuse.OpenTelemetry.TraceContext.extract([])
      {:error, :no_trace_context}

  """
  @spec extract(list({String.t(), String.t()}) | map()) :: {:ok, t()} | {:error, atom()}
  def extract(headers) when is_list(headers) do
    headers_map = normalize_headers(headers)
    extract(headers_map)
  end

  def extract(headers) when is_map(headers) do
    case Map.get(headers, "traceparent") do
      nil ->
        {:error, :no_trace_context}

      traceparent ->
        parse_traceparent(traceparent, Map.get(headers, "tracestate"))
    end
  end

  @doc """
  Extracts trace context, returning nil on failure.

  ## Examples

      iex> headers = [{"traceparent", "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01"}]
      iex> context = Langfuse.OpenTelemetry.TraceContext.extract!(headers)
      iex> context.trace_id
      "0af7651916cd43dd8448eb211c80319c"

      iex> Langfuse.OpenTelemetry.TraceContext.extract!([])
      nil

  """
  @spec extract!(list({String.t(), String.t()}) | map()) :: t() | nil
  def extract!(headers) do
    case extract(headers) do
      {:ok, context} -> context
      {:error, _} -> nil
    end
  end

  @doc """
  Generates W3C Trace Context headers for outgoing requests.

  Creates `traceparent` and optionally `tracestate` headers for propagating
  trace context to downstream services.

  ## Options

    * `:sampled` - Whether the trace is sampled (default: true)
    * `:tracestate` - Optional vendor-specific trace state

  ## Examples

      iex> Langfuse.OpenTelemetry.TraceContext.inject("abc123def456", "span789")
      [{"traceparent", "00-abc123def456000000000000000000000-span78900000000000-01"}]

      iex> Langfuse.OpenTelemetry.TraceContext.inject(
      ...>   "0af7651916cd43dd8448eb211c80319c",
      ...>   "b7ad6b7169203331",
      ...>   sampled: false
      ...> )
      [{"traceparent", "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-00"}]

  """
  @spec inject(String.t(), String.t(), keyword()) :: list({String.t(), String.t()})
  def inject(trace_id, span_id, opts \\ []) do
    sampled = Keyword.get(opts, :sampled, true)
    tracestate = Keyword.get(opts, :tracestate)

    trace_id_padded = String.pad_trailing(trace_id, 32, "0") |> String.slice(0, 32)
    span_id_padded = String.pad_trailing(span_id, 16, "0") |> String.slice(0, 16)
    flags = if sampled, do: "01", else: "00"

    traceparent = "00-#{trace_id_padded}-#{span_id_padded}-#{flags}"

    headers = [{"traceparent", traceparent}]

    if tracestate do
      headers ++ [{"tracestate", tracestate}]
    else
      headers
    end
  end

  @doc """
  Creates a new trace context with a fresh trace ID and span ID.

  Useful for starting a new distributed trace.

  ## Options

    * `:sampled` - Whether to sample this trace (default: true)

  ## Examples

      iex> context = Langfuse.OpenTelemetry.TraceContext.new()
      iex> String.length(context.trace_id)
      32
      iex> String.length(context.parent_id)
      16
      iex> context.sampled
      true

  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    sampled = Keyword.get(opts, :sampled, true)

    %{
      trace_id: generate_trace_id(),
      parent_id: generate_span_id(),
      trace_flags: if(sampled, do: 1, else: 0),
      sampled: sampled,
      tracestate: nil
    }
  end

  @doc """
  Creates a child context from an existing trace context.

  Generates a new span ID while preserving the trace ID for correlation.

  ## Examples

      iex> parent = %{trace_id: "abc123", parent_id: "def456", trace_flags: 1, sampled: true, tracestate: nil}
      iex> child = Langfuse.OpenTelemetry.TraceContext.child(parent)
      iex> child.trace_id
      "abc123"
      iex> child.parent_id != "def456"
      true

  """
  @spec child(t()) :: t()
  def child(%{trace_id: trace_id, trace_flags: flags, sampled: sampled, tracestate: tracestate}) do
    %{
      trace_id: trace_id,
      parent_id: generate_span_id(),
      trace_flags: flags,
      sampled: sampled,
      tracestate: tracestate
    }
  end

  @doc """
  Converts a trace context to headers suitable for HTTP propagation.

  ## Examples

      iex> context = %{trace_id: "0af7651916cd43dd8448eb211c80319c", parent_id: "b7ad6b7169203331", trace_flags: 1, sampled: true, tracestate: nil}
      iex> Langfuse.OpenTelemetry.TraceContext.to_headers(context)
      [{"traceparent", "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01"}]

  """
  @spec to_headers(t()) :: list({String.t(), String.t()})
  def to_headers(%{trace_id: trace_id, parent_id: parent_id, sampled: sampled} = context) do
    inject(trace_id, parent_id, sampled: sampled, tracestate: context[:tracestate])
  end

  defp parse_traceparent(traceparent, tracestate) do
    traceparent_lower = String.downcase(traceparent)

    case Regex.run(@traceparent_regex, traceparent_lower) do
      [_, trace_id, parent_id, flags_hex] ->
        {flags, _} = Integer.parse(flags_hex, 16)

        {:ok,
         %{
           trace_id: trace_id,
           parent_id: parent_id,
           trace_flags: flags,
           sampled: Bitwise.band(flags, 1) == 1,
           tracestate: tracestate
         }}

      nil ->
        {:error, :invalid_traceparent}
    end
  end

  defp normalize_headers(headers) do
    Enum.reduce(headers, %{}, fn {key, value}, acc ->
      Map.put(acc, String.downcase(to_string(key)), value)
    end)
  end

  defp generate_trace_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end

  defp generate_span_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
end
