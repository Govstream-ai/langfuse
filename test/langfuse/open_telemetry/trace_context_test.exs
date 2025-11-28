defmodule Langfuse.OpenTelemetry.TraceContextTest do
  use ExUnit.Case, async: true

  alias Langfuse.OpenTelemetry.TraceContext

  describe "extract/1" do
    test "extracts valid traceparent header from list" do
      headers = [{"traceparent", "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01"}]

      assert {:ok, context} = TraceContext.extract(headers)
      assert context.trace_id == "0af7651916cd43dd8448eb211c80319c"
      assert context.parent_id == "b7ad6b7169203331"
      assert context.trace_flags == 1
      assert context.sampled == true
    end

    test "extracts valid traceparent header from map" do
      headers = %{"traceparent" => "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-00"}

      assert {:ok, context} = TraceContext.extract(headers)
      assert context.trace_id == "0af7651916cd43dd8448eb211c80319c"
      assert context.parent_id == "b7ad6b7169203331"
      assert context.trace_flags == 0
      assert context.sampled == false
    end

    test "handles case-insensitive header names" do
      headers = [{"Traceparent", "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01"}]

      assert {:ok, context} = TraceContext.extract(headers)
      assert context.trace_id == "0af7651916cd43dd8448eb211c80319c"
    end

    test "handles uppercase traceparent values" do
      headers = [{"traceparent", "00-0AF7651916CD43DD8448EB211C80319C-B7AD6B7169203331-01"}]

      assert {:ok, context} = TraceContext.extract(headers)
      assert context.trace_id == "0af7651916cd43dd8448eb211c80319c"
    end

    test "extracts tracestate when present" do
      headers = [
        {"traceparent", "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01"},
        {"tracestate", "langfuse=abc123"}
      ]

      assert {:ok, context} = TraceContext.extract(headers)
      assert context.tracestate == "langfuse=abc123"
    end

    test "returns error for missing traceparent" do
      assert {:error, :no_trace_context} = TraceContext.extract([])
      assert {:error, :no_trace_context} = TraceContext.extract(%{})
    end

    test "returns error for invalid traceparent format" do
      headers = [{"traceparent", "invalid-format"}]
      assert {:error, :invalid_traceparent} = TraceContext.extract(headers)
    end

    test "returns error for wrong version" do
      headers = [{"traceparent", "01-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01"}]
      assert {:error, :invalid_traceparent} = TraceContext.extract(headers)
    end

    test "returns error for wrong trace_id length" do
      headers = [{"traceparent", "00-0af7651916cd43dd-b7ad6b7169203331-01"}]
      assert {:error, :invalid_traceparent} = TraceContext.extract(headers)
    end

    test "returns error for wrong parent_id length" do
      headers = [{"traceparent", "00-0af7651916cd43dd8448eb211c80319c-b7ad6b-01"}]
      assert {:error, :invalid_traceparent} = TraceContext.extract(headers)
    end
  end

  describe "extract!/1" do
    test "returns context for valid headers" do
      headers = [{"traceparent", "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01"}]
      context = TraceContext.extract!(headers)

      assert context.trace_id == "0af7651916cd43dd8448eb211c80319c"
    end

    test "returns nil for missing or invalid headers" do
      assert TraceContext.extract!([]) == nil
      assert TraceContext.extract!([{"traceparent", "invalid"}]) == nil
    end
  end

  describe "inject/3" do
    test "generates traceparent header" do
      headers =
        TraceContext.inject(
          "0af7651916cd43dd8448eb211c80319c",
          "b7ad6b7169203331"
        )

      assert [{"traceparent", traceparent}] = headers
      assert traceparent == "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01"
    end

    test "respects sampled option" do
      headers =
        TraceContext.inject(
          "0af7651916cd43dd8448eb211c80319c",
          "b7ad6b7169203331",
          sampled: false
        )

      assert [{"traceparent", traceparent}] = headers
      assert String.ends_with?(traceparent, "-00")
    end

    test "includes tracestate when provided" do
      headers =
        TraceContext.inject(
          "0af7651916cd43dd8448eb211c80319c",
          "b7ad6b7169203331",
          tracestate: "vendor=value"
        )

      assert length(headers) == 2
      assert {"tracestate", "vendor=value"} in headers
    end

    test "pads short trace_id" do
      headers = TraceContext.inject("abc", "def")
      [{"traceparent", traceparent}] = headers

      assert traceparent =~ ~r/^00-abc0{29}-def0{13}-01$/
    end

    test "truncates long trace_id" do
      long_id = String.duplicate("a", 64)
      headers = TraceContext.inject(long_id, "b7ad6b7169203331")
      [{"traceparent", traceparent}] = headers

      [_, trace_id, _, _] = String.split(traceparent, "-")
      assert String.length(trace_id) == 32
    end
  end

  describe "new/1" do
    test "generates valid trace context" do
      context = TraceContext.new()

      assert String.length(context.trace_id) == 32
      assert String.length(context.parent_id) == 16
      assert context.trace_flags == 1
      assert context.sampled == true
      assert context.tracestate == nil
    end

    test "respects sampled option" do
      context = TraceContext.new(sampled: false)

      assert context.trace_flags == 0
      assert context.sampled == false
    end

    test "generates unique IDs" do
      context1 = TraceContext.new()
      context2 = TraceContext.new()

      assert context1.trace_id != context2.trace_id
      assert context1.parent_id != context2.parent_id
    end
  end

  describe "child/1" do
    test "preserves trace_id" do
      parent = %{
        trace_id: "abc123def456",
        parent_id: "oldspan",
        trace_flags: 1,
        sampled: true,
        tracestate: nil
      }

      child = TraceContext.child(parent)

      assert child.trace_id == "abc123def456"
      assert child.parent_id != "oldspan"
      assert String.length(child.parent_id) == 16
    end

    test "preserves trace_flags and sampled" do
      parent = %{
        trace_id: "abc123",
        parent_id: "def456",
        trace_flags: 0,
        sampled: false,
        tracestate: "vendor=value"
      }

      child = TraceContext.child(parent)

      assert child.trace_flags == 0
      assert child.sampled == false
      assert child.tracestate == "vendor=value"
    end
  end

  describe "to_headers/1" do
    test "converts context to headers" do
      context = %{
        trace_id: "0af7651916cd43dd8448eb211c80319c",
        parent_id: "b7ad6b7169203331",
        trace_flags: 1,
        sampled: true,
        tracestate: nil
      }

      headers = TraceContext.to_headers(context)

      assert [{"traceparent", "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01"}] =
               headers
    end

    test "includes tracestate in headers" do
      context = %{
        trace_id: "0af7651916cd43dd8448eb211c80319c",
        parent_id: "b7ad6b7169203331",
        trace_flags: 1,
        sampled: true,
        tracestate: "langfuse=test"
      }

      headers = TraceContext.to_headers(context)

      assert {"tracestate", "langfuse=test"} in headers
    end
  end

  describe "roundtrip" do
    test "extract -> inject produces equivalent traceparent" do
      original = "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01"
      headers = [{"traceparent", original}]

      {:ok, context} = TraceContext.extract(headers)
      [{"traceparent", roundtrip}] = TraceContext.to_headers(context)

      assert roundtrip == original
    end
  end
end
