defmodule Langfuse.OpenTelemetry.SetupTest do
  use ExUnit.Case, async: true

  alias Langfuse.OpenTelemetry.Setup

  describe "exporter_config/1" do
    test "returns OTLP configuration with defaults" do
      config = Setup.exporter_config()

      assert config[:otlp_protocol] == :http_protobuf
      assert config[:otlp_endpoint] =~ "/api/public/otel/v1/traces"
      assert [{"Authorization", auth}] = config[:otlp_headers]
      assert String.starts_with?(auth, "Basic ")
    end

    test "uses custom host" do
      config = Setup.exporter_config(host: "https://custom.langfuse.com")

      assert config[:otlp_endpoint] == "https://custom.langfuse.com/api/public/otel/v1/traces"
    end

    test "uses custom credentials" do
      config =
        Setup.exporter_config(
          public_key: "pk-test",
          secret_key: "sk-test"
        )

      expected_auth = "Basic " <> Base.encode64("pk-test:sk-test")
      assert [{"Authorization", ^expected_auth}] = config[:otlp_headers]
    end
  end

  describe "configure_exporter/1" do
    test "sets application env for opentelemetry_exporter" do
      Setup.configure_exporter(
        host: "https://test.langfuse.com",
        public_key: "pk-test",
        secret_key: "sk-test"
      )

      assert Application.get_env(:opentelemetry_exporter, :otlp_protocol) == :http_protobuf

      assert Application.get_env(:opentelemetry_exporter, :otlp_endpoint) ==
               "https://test.langfuse.com/api/public/otel/v1/traces"

      headers = Application.get_env(:opentelemetry_exporter, :otlp_headers)
      assert [{"Authorization", _}] = headers
    end
  end

  describe "sdk_config/1" do
    test "returns SDK configuration" do
      config = Setup.sdk_config()

      assert config[:span_processor] == :batch
      assert config[:traces_exporter] == :otlp
      assert config[:resource][:service][:name]
    end

    test "allows custom service name" do
      config = Setup.sdk_config(service_name: "my-service")

      assert config[:resource][:service][:name] == "my-service"
    end
  end

  describe "status/0" do
    test "returns status info" do
      assert {:ok, info} = Setup.status()
      assert info.opentelemetry_loaded == true
      assert is_boolean(info.tracer_provider)
      assert is_boolean(info.langfuse_configured)
    end
  end

  describe "processor_config/1" do
    test "returns processor tuple with default config" do
      assert {Langfuse.OpenTelemetry.SpanProcessor, config} = Setup.processor_config()
      assert config.enabled == true
      assert config.filter_fn == nil
    end

    test "accepts enabled option" do
      assert {_, config} = Setup.processor_config(enabled: false)
      assert config.enabled == false
    end

    test "accepts filter_fn option" do
      filter = fn _span -> true end
      assert {_, config} = Setup.processor_config(filter_fn: filter)
      assert config.filter_fn == filter
    end
  end
end
