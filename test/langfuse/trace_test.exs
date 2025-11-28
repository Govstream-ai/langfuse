defmodule Langfuse.TraceTest do
  use ExUnit.Case, async: true

  alias Langfuse.Trace

  describe "new/1" do
    test "creates a trace with required fields" do
      trace = Trace.new(name: "test-trace")

      assert trace.name == "test-trace"
      assert is_binary(trace.id)
      assert String.length(trace.id) == 24
      assert %DateTime{} = trace.timestamp
    end

    test "creates a trace with optional fields" do
      trace =
        Trace.new(
          name: "test-trace",
          user_id: "user-123",
          session_id: "session-456",
          metadata: %{key: "value"},
          tags: ["prod", "v1"],
          public: true,
          input: %{prompt: "hello"},
          output: %{response: "world"}
        )

      assert trace.name == "test-trace"
      assert trace.user_id == "user-123"
      assert trace.session_id == "session-456"
      assert trace.metadata == %{key: "value"}
      assert trace.tags == ["prod", "v1"]
      assert trace.public == true
      assert trace.input == %{prompt: "hello"}
      assert trace.output == %{response: "world"}
    end

    test "allows custom id" do
      trace = Trace.new(name: "test-trace", id: "custom-id-123")

      assert trace.id == "custom-id-123"
    end

    test "allows custom timestamp" do
      timestamp = ~U[2025-01-15 10:30:00Z]
      trace = Trace.new(name: "test-trace", timestamp: timestamp)

      assert trace.timestamp == timestamp
    end

    test "raises when name is missing" do
      assert_raise KeyError, fn ->
        Trace.new([])
      end
    end
  end

  describe "update/2" do
    test "updates trace fields" do
      trace = Trace.new(name: "original")
      updated = Trace.update(trace, name: "updated", user_id: "user-456")

      assert updated.name == "updated"
      assert updated.user_id == "user-456"
      assert updated.id == trace.id
    end

    test "preserves unchanged fields" do
      trace = Trace.new(name: "test", user_id: "user-123", session_id: "session-456")
      updated = Trace.update(trace, name: "updated")

      assert updated.name == "updated"
      assert updated.user_id == "user-123"
      assert updated.session_id == "session-456"
    end
  end

  describe "get_id/1" do
    test "returns the trace id" do
      trace = Trace.new(name: "test", id: "my-trace-id")

      assert Trace.get_id(trace) == "my-trace-id"
    end
  end

  describe "get_session_id/1" do
    test "returns the session id" do
      trace = Trace.new(name: "test", session_id: "session-123")

      assert Trace.get_session_id(trace) == "session-123"
    end

    test "returns nil when no session id" do
      trace = Trace.new(name: "test")

      assert Trace.get_session_id(trace) == nil
    end
  end
end
