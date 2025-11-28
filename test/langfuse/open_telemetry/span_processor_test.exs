defmodule Langfuse.OpenTelemetry.SpanProcessorTest do
  @moduledoc """
  Integration tests for SpanProcessor.

  These tests require the application-supervised Config and Ingestion processes
  because SpanProcessor calls them by module name. We use `ensure_started` to
  handle cases where processes may already be running from the application supervisor.

  For unit testing of attribute mapping logic, see AttributeMapperTest which
  tests pure functions without process dependencies.
  """
  use ExUnit.Case, async: false

  import Mox

  alias Langfuse.OpenTelemetry.SpanProcessor

  setup :verify_on_exit!

  setup do
    Langfuse.HTTPMock
    |> stub(:post, fn _path, _body ->
      {:ok, %{"successes" => [], "errors" => []}}
    end)

    ensure_started(Langfuse.Config, fn -> Langfuse.Config.start_link([]) end)

    ensure_started(Langfuse.Ingestion, fn ->
      Langfuse.Ingestion.start_link(flush_interval: 100_000)
    end)

    :ok
  end

  defp ensure_started(name, start_fn) do
    case Process.whereis(name) do
      nil ->
        case start_fn.() do
          {:ok, _pid} -> :ok
          {:error, {:already_started, _pid}} -> :ok
        end

      _pid ->
        :ok
    end
  end

  describe "on_start/3" do
    test "returns span unchanged when enabled" do
      span = create_mock_span()
      assert SpanProcessor.on_start(nil, span, %{enabled: true}) == span
    end

    test "returns span unchanged when disabled" do
      span = create_mock_span()
      assert SpanProcessor.on_start(nil, span, %{enabled: false}) == span
    end
  end

  describe "on_end/2" do
    test "returns :dropped when disabled" do
      span = create_mock_span()
      assert SpanProcessor.on_end(span, %{enabled: false}) == :dropped
    end

    test "returns :dropped when filter_fn returns false" do
      span = create_mock_span()

      config = %{
        enabled: true,
        filter_fn: fn _span -> false end
      }

      assert SpanProcessor.on_end(span, config) == :dropped
    end

    test "processes span when filter_fn returns true" do
      span = create_mock_span()

      config = %{
        enabled: true,
        filter_fn: fn _span -> true end
      }

      assert SpanProcessor.on_end(span, config) == true
    end

    test "processes root span and creates trace event" do
      span = create_mock_span(parent_span_id: 0)

      assert SpanProcessor.on_end(span, %{}) == true
    end

    test "processes generation span with gen_ai attributes" do
      span =
        create_mock_span(
          attributes: %{
            "gen_ai.request.model" => "gpt-4",
            "gen_ai.usage.input_tokens" => 100
          }
        )

      assert SpanProcessor.on_end(span, %{}) == true
    end

    test "processes regular span without gen_ai attributes" do
      span =
        create_mock_span(
          attributes: %{
            "http.method" => "GET",
            "http.url" => "https://api.example.com"
          }
        )

      assert SpanProcessor.on_end(span, %{}) == true
    end
  end

  describe "force_flush/1" do
    test "calls Ingestion.flush" do
      assert SpanProcessor.force_flush(%{}) == :ok
    end
  end

  defp create_mock_span(opts \\ []) do
    trace_id = Keyword.get(opts, :trace_id, :rand.uniform(1_000_000_000_000_000))
    span_id = Keyword.get(opts, :span_id, :rand.uniform(1_000_000_000))
    parent_span_id = Keyword.get(opts, :parent_span_id, :rand.uniform(1_000_000_000))
    name = Keyword.get(opts, :name, "test-span")
    kind = Keyword.get(opts, :kind, :internal)
    start_time = Keyword.get(opts, :start_time, System.system_time(:nanosecond))
    end_time = Keyword.get(opts, :end_time, System.system_time(:nanosecond) + 1_000_000)
    attributes = Keyword.get(opts, :attributes, %{})
    events = Keyword.get(opts, :events, [])
    links = Keyword.get(opts, :links, [])
    status = Keyword.get(opts, :status, {:status, :ok, ""})
    is_recording = Keyword.get(opts, :is_recording, true)

    {trace_id, span_id, parent_span_id, name, kind, start_time, end_time, attributes, events,
     links, status, is_recording}
  end
end
