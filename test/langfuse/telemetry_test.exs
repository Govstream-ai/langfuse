defmodule Langfuse.TelemetryTest do
  use ExUnit.Case, async: true

  alias Langfuse.Telemetry

  describe "events/0" do
    test "returns all telemetry events" do
      events = Telemetry.events()

      assert is_list(events)
      assert length(events) == 7

      assert [:langfuse, :http, :request, :start] in events
      assert [:langfuse, :http, :request, :stop] in events
      assert [:langfuse, :ingestion, :flush, :start] in events
      assert [:langfuse, :ingestion, :flush, :stop] in events
      assert [:langfuse, :ingestion, :flush, :error] in events
      assert [:langfuse, :prompt, :fetch, :start] in events
      assert [:langfuse, :prompt, :fetch, :stop] in events
    end
  end

  describe "attach_default_logger/1" do
    test "attaches logger handler" do
      assert :ok = Telemetry.attach_default_logger()
      assert :ok = Telemetry.detach_default_logger()
    end

    test "returns error when already attached" do
      assert :ok = Telemetry.attach_default_logger()
      assert {:error, :already_exists} = Telemetry.attach_default_logger()
      assert :ok = Telemetry.detach_default_logger()
    end
  end

  describe "detach_default_logger/0" do
    test "returns error when not attached" do
      assert {:error, :not_found} = Telemetry.detach_default_logger()
    end
  end
end
