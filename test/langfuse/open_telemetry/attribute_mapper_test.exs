defmodule Langfuse.OpenTelemetry.AttributeMapperTest do
  use ExUnit.Case, async: true

  alias Langfuse.OpenTelemetry.AttributeMapper

  describe "map_attributes/1" do
    test "maps gen_ai.request.model to model" do
      attrs = %{"gen_ai.request.model" => "gpt-4"}
      assert AttributeMapper.map_attributes(attrs) == %{model: "gpt-4"}
    end

    test "maps gen_ai.response.model to model" do
      attrs = %{"gen_ai.response.model" => "gpt-4-turbo"}
      assert AttributeMapper.map_attributes(attrs) == %{model: "gpt-4-turbo"}
    end

    test "maps usage tokens to nested usage map" do
      attrs = %{
        "gen_ai.usage.input_tokens" => 100,
        "gen_ai.usage.output_tokens" => 50,
        "gen_ai.usage.total_tokens" => 150
      }

      result = AttributeMapper.map_attributes(attrs)
      assert result.usage.input == 100
      assert result.usage.output == 50
      assert result.usage.total == 150
    end

    test "maps langfuse.user.id to user_id" do
      attrs = %{"langfuse.user.id" => "user-123"}
      assert AttributeMapper.map_attributes(attrs) == %{user_id: "user-123"}
    end

    test "maps user.id as fallback" do
      attrs = %{"user.id" => "user-456"}
      assert AttributeMapper.map_attributes(attrs) == %{user_id: "user-456"}
    end

    test "maps langfuse.session.id to session_id" do
      attrs = %{"langfuse.session.id" => "sess-789"}
      assert AttributeMapper.map_attributes(attrs) == %{session_id: "sess-789"}
    end

    test "maps langfuse.trace.name to trace_name" do
      attrs = %{"langfuse.trace.name" => "my-trace"}
      assert AttributeMapper.map_attributes(attrs) == %{trace_name: "my-trace"}
    end

    test "maps langfuse.trace.tags to tags as list" do
      attrs = %{"langfuse.trace.tags" => ["tag1", "tag2"]}
      assert AttributeMapper.map_attributes(attrs) == %{tags: ["tag1", "tag2"]}
    end

    test "parses comma-separated tags string" do
      attrs = %{"langfuse.trace.tags" => "tag1,tag2,tag3"}
      assert AttributeMapper.map_attributes(attrs) == %{tags: ["tag1", "tag2", "tag3"]}
    end

    test "maps gen_ai.prompt to input" do
      attrs = %{"gen_ai.prompt" => "Hello, world!"}
      assert AttributeMapper.map_attributes(attrs) == %{input: "Hello, world!"}
    end

    test "maps gen_ai.completion to output" do
      attrs = %{"gen_ai.completion" => "Hi there!"}
      assert AttributeMapper.map_attributes(attrs) == %{output: "Hi there!"}
    end

    test "parses JSON values in input/output" do
      attrs = %{"gen_ai.prompt" => ~s({"messages": [{"role": "user", "content": "Hi"}]})}
      result = AttributeMapper.map_attributes(attrs)
      assert result.input == %{"messages" => [%{"role" => "user", "content" => "Hi"}]}
    end

    test "maps langfuse.observation.input to input" do
      attrs = %{"langfuse.observation.input" => "test input"}
      assert AttributeMapper.map_attributes(attrs) == %{input: "test input"}
    end

    test "maps langfuse.observation.output to output" do
      attrs = %{"langfuse.observation.output" => "test output"}
      assert AttributeMapper.map_attributes(attrs) == %{output: "test output"}
    end

    test "maps langfuse.observation.level and uppercases it" do
      attrs = %{"langfuse.observation.level" => "error"}
      assert AttributeMapper.map_attributes(attrs) == %{level: "ERROR"}
    end

    test "maps langfuse.observation.status_message" do
      attrs = %{"langfuse.observation.status_message" => "Operation failed"}
      assert AttributeMapper.map_attributes(attrs) == %{status_message: "Operation failed"}
    end

    test "maps model parameters" do
      attrs = %{
        "gen_ai.request.temperature" => 0.7,
        "gen_ai.request.max_tokens" => 1000,
        "gen_ai.request.top_p" => 0.9
      }

      result = AttributeMapper.map_attributes(attrs)
      assert result.model_parameters.temperature == 0.7
      assert result.model_parameters.max_tokens == 1000
      assert result.model_parameters.top_p == 0.9
    end

    test "maps llm.token_count.* attributes" do
      attrs = %{
        "llm.token_count.prompt" => 200,
        "llm.token_count.completion" => 100,
        "llm.token_count.total" => 300
      }

      result = AttributeMapper.map_attributes(attrs)
      assert result.usage.input == 200
      assert result.usage.output == 100
      assert result.usage.total == 300
    end

    test "maps OpenInference input.value/output.value" do
      attrs = %{
        "input.value" => "input text",
        "output.value" => "output text"
      }

      result = AttributeMapper.map_attributes(attrs)
      assert result.input == "input text"
      assert result.output == "output text"
    end

    test "maps MLflow spanInputs/spanOutputs" do
      attrs = %{
        "mlflow.spanInputs" => ~s({"prompt": "test"}),
        "mlflow.spanOutputs" => ~s({"response": "result"})
      }

      result = AttributeMapper.map_attributes(attrs)
      assert result.input == %{"prompt" => "test"}
      assert result.output == %{"response" => "result"}
    end

    test "maps langfuse.trace.metadata.* to trace_metadata" do
      attrs = %{
        "langfuse.trace.metadata.key1" => "value1",
        "langfuse.trace.metadata.key2" => "value2"
      }

      result = AttributeMapper.map_attributes(attrs)
      assert result.trace_metadata == %{"key1" => "value1", "key2" => "value2"}
    end

    test "maps langfuse.observation.metadata.* to metadata" do
      attrs = %{
        "langfuse.observation.metadata.custom" => "data"
      }

      result = AttributeMapper.map_attributes(attrs)
      assert result.metadata == %{"custom" => "data"}
    end

    test "maps gen_ai.prompt.N.role/content to prompt_messages" do
      attrs = %{
        "gen_ai.prompt.0.role" => "system",
        "gen_ai.prompt.0.content" => "You are helpful",
        "gen_ai.prompt.1.role" => "user",
        "gen_ai.prompt.1.content" => "Hello"
      }

      result = AttributeMapper.map_attributes(attrs)

      assert result.input == [
               %{"role" => "system", "content" => "You are helpful"},
               %{"role" => "user", "content" => "Hello"}
             ]
    end

    test "maps gen_ai.completion.N.* to completion_messages" do
      attrs = %{
        "gen_ai.completion.0.role" => "assistant",
        "gen_ai.completion.0.content" => "Hello! How can I help?"
      }

      result = AttributeMapper.map_attributes(attrs)
      assert result.output == [%{"role" => "assistant", "content" => "Hello! How can I help?"}]
    end

    test "maps langfuse.observation.prompt.name and version" do
      attrs = %{
        "langfuse.observation.prompt.name" => "my-prompt",
        "langfuse.observation.prompt.version" => 2
      }

      result = AttributeMapper.map_attributes(attrs)
      assert result.prompt_name == "my-prompt"
      assert result.prompt_version == 2
    end

    test "maps environment attributes" do
      attrs = %{"langfuse.environment" => "production"}
      assert AttributeMapper.map_attributes(attrs) == %{environment: "production"}

      attrs2 = %{"deployment.environment" => "staging"}
      assert AttributeMapper.map_attributes(attrs2) == %{environment: "staging"}
    end

    test "maps gen_ai.usage.cost to cost" do
      attrs = %{"gen_ai.usage.cost" => 0.0025}
      assert AttributeMapper.map_attributes(attrs) == %{cost: %{total: 0.0025}}
    end

    test "combines multiple attribute types" do
      attrs = %{
        "gen_ai.request.model" => "claude-3",
        "langfuse.user.id" => "user-123",
        "gen_ai.usage.input_tokens" => 100,
        "gen_ai.request.temperature" => 0.5
      }

      result = AttributeMapper.map_attributes(attrs)
      assert result.model == "claude-3"
      assert result.user_id == "user-123"
      assert result.usage.input == 100
      assert result.model_parameters.temperature == 0.5
    end

    test "returns empty map for empty input" do
      assert AttributeMapper.map_attributes(%{}) == %{}
    end

    test "returns empty map for non-map input" do
      assert AttributeMapper.map_attributes(nil) == %{}
      assert AttributeMapper.map_attributes([]) == %{}
    end

    test "ignores unknown attributes" do
      attrs = %{
        "unknown.attribute" => "value",
        "gen_ai.request.model" => "gpt-4"
      }

      assert AttributeMapper.map_attributes(attrs) == %{model: "gpt-4"}
    end
  end
end
