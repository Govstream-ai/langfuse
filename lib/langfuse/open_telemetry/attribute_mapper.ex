defmodule Langfuse.OpenTelemetry.AttributeMapper do
  @moduledoc """
  Maps OpenTelemetry span attributes to Langfuse observation fields.

  This module provides comprehensive mapping from OpenTelemetry semantic
  conventions to Langfuse's data model, supporting:

    * GenAI semantic conventions (`gen_ai.*`)
    * Langfuse-specific attributes (`langfuse.*`)
    * OpenInference attributes (`input.value`, `output.value`)
    * MLflow attributes (`mlflow.*`)
    * LLM common attributes (`llm.*`)

  ## Attribute Precedence

  When multiple attributes map to the same Langfuse field, the precedence is:

    1. `langfuse.*` namespace (highest priority)
    2. `gen_ai.*` semantic conventions
    3. Framework-specific attributes (OpenInference, MLflow)
    4. Generic attributes (lowest priority)

  ## Trace-Level Attributes

  | OpenTelemetry Attribute | Langfuse Field |
  |-------------------------|----------------|
  | `langfuse.trace.name` | `name` |
  | `langfuse.user.id`, `user.id` | `userId` |
  | `langfuse.session.id`, `session.id` | `sessionId` |
  | `langfuse.trace.tags` | `tags` |
  | `langfuse.trace.public` | `public` |
  | `langfuse.trace.input` | `input` |
  | `langfuse.trace.output` | `output` |
  | `langfuse.release` | `release` |
  | `langfuse.version` | `version` |
  | `langfuse.environment`, `deployment.environment` | `environment` |

  ## Observation-Level Attributes

  | OpenTelemetry Attribute | Langfuse Field |
  |-------------------------|----------------|
  | `langfuse.observation.input`, `gen_ai.prompt`, `input.value` | `input` |
  | `langfuse.observation.output`, `gen_ai.completion`, `output.value` | `output` |
  | `langfuse.observation.level` | `level` |
  | `langfuse.observation.status_message` | `statusMessage` |

  ## Generation-Specific Attributes

  | OpenTelemetry Attribute | Langfuse Field |
  |-------------------------|----------------|
  | `gen_ai.request.model`, `gen_ai.response.model`, `model` | `model` |
  | `gen_ai.request.*` | `modelParameters` |
  | `gen_ai.usage.*`, `llm.token_count.*` | `usage` |
  | `gen_ai.usage.cost` | `cost` |
  | `langfuse.observation.prompt.name` | `promptName` |
  | `langfuse.observation.prompt.version` | `promptVersion` |
  | `langfuse.observation.completion_start_time` | `completionStartTime` |

  """

  @doc """
  Maps OpenTelemetry span attributes to Langfuse observation fields.

  Takes a map of OTEL attributes and returns a map with Langfuse field names.

  ## Examples

      iex> attrs = %{"gen_ai.request.model" => "gpt-4", "gen_ai.usage.input_tokens" => 100}
      iex> Langfuse.OpenTelemetry.AttributeMapper.map_attributes(attrs)
      %{model: "gpt-4", usage: %{input: 100}}

      iex> attrs = %{"langfuse.user.id" => "user-123", "langfuse.session.id" => "sess-456"}
      iex> Langfuse.OpenTelemetry.AttributeMapper.map_attributes(attrs)
      %{user_id: "user-123", session_id: "sess-456"}

  """
  @spec map_attributes(map()) :: map()
  def map_attributes(attributes) when is_map(attributes) do
    attributes
    |> Enum.reduce(%{}, fn {key, value}, acc ->
      key_str = to_string(key)

      case map_attribute(key_str, value) do
        nil -> acc
        {field, mapped_value} -> deep_merge(acc, %{field => mapped_value})
      end
    end)
    |> post_process()
  end

  def map_attributes(_), do: %{}

  defp map_attribute("langfuse.trace.name", value), do: {:trace_name, value}
  defp map_attribute("langfuse.user.id", value), do: {:user_id, value}
  defp map_attribute("user.id", value), do: {:user_id, value}
  defp map_attribute("langfuse.session.id", value), do: {:session_id, value}
  defp map_attribute("session.id", value), do: {:session_id, value}
  defp map_attribute("langfuse.trace.tags", value), do: {:tags, normalize_tags(value)}
  defp map_attribute("langfuse.trace.public", value), do: {:public, value}

  defp map_attribute("langfuse.trace.input", value),
    do: {:trace_input, parse_json_or_string(value)}

  defp map_attribute("langfuse.trace.output", value),
    do: {:trace_output, parse_json_or_string(value)}

  defp map_attribute("langfuse.release", value), do: {:release, value}
  defp map_attribute("langfuse.version", value), do: {:version, value}
  defp map_attribute("langfuse.environment", value), do: {:environment, value}
  defp map_attribute("deployment.environment", value), do: {:environment, value}
  defp map_attribute("deployment.environment.name", value), do: {:environment, value}

  defp map_attribute("langfuse.trace.metadata." <> key, value),
    do: {:trace_metadata, %{key => value}}

  defp map_attribute("langfuse.observation.input", value),
    do: {:input, parse_json_or_string(value)}

  defp map_attribute("langfuse.observation.output", value),
    do: {:output, parse_json_or_string(value)}

  defp map_attribute("langfuse.observation.level", value), do: {:level, String.upcase(value)}
  defp map_attribute("langfuse.observation.status_message", value), do: {:status_message, value}

  defp map_attribute("langfuse.observation.metadata." <> key, value),
    do: {:metadata, %{key => value}}

  defp map_attribute("langfuse.observation.model.name", value), do: {:model, value}

  defp map_attribute("langfuse.observation.model.parameters", value),
    do: {:model_parameters, parse_json_or_string(value)}

  defp map_attribute("langfuse.observation.usage_details", value),
    do: {:usage, parse_json_or_string(value)}

  defp map_attribute("langfuse.observation.cost_details", value),
    do: {:cost, parse_json_or_string(value)}

  defp map_attribute("langfuse.observation.prompt.name", value), do: {:prompt_name, value}
  defp map_attribute("langfuse.observation.prompt.version", value), do: {:prompt_version, value}

  defp map_attribute("langfuse.observation.completion_start_time", value),
    do: {:completion_start_time, value}

  defp map_attribute("langfuse.observation.type", value), do: {:observation_type, value}

  defp map_attribute("gen_ai.request.model", value), do: {:model, value}
  defp map_attribute("gen_ai.response.model", value), do: {:model, value}
  defp map_attribute("llm.model_name", value), do: {:model, value}
  defp map_attribute("model", value), do: {:model, value}

  defp map_attribute("gen_ai.prompt", value), do: {:input, parse_json_or_string(value)}
  defp map_attribute("gen_ai.completion", value), do: {:output, parse_json_or_string(value)}
  defp map_attribute("gen_ai.prompt_json", value), do: {:input, parse_json_or_string(value)}
  defp map_attribute("gen_ai.completion_json", value), do: {:output, parse_json_or_string(value)}

  defp map_attribute("input.value", value), do: {:input, parse_json_or_string(value)}
  defp map_attribute("output.value", value), do: {:output, parse_json_or_string(value)}
  defp map_attribute("mlflow.spanInputs", value), do: {:input, parse_json_or_string(value)}
  defp map_attribute("mlflow.spanOutputs", value), do: {:output, parse_json_or_string(value)}

  defp map_attribute("gen_ai.prompt." <> index_and_field, value) do
    case parse_prompt_attribute(index_and_field) do
      {index, field} -> {:prompt_messages, %{index => %{field => value}}}
      nil -> nil
    end
  end

  defp map_attribute("gen_ai.completion." <> index_and_field, value) do
    case parse_prompt_attribute(index_and_field) do
      {index, field} -> {:completion_messages, %{index => %{field => value}}}
      nil -> nil
    end
  end

  defp map_attribute("gen_ai.usage.input_tokens", value), do: {:usage, %{input: value}}
  defp map_attribute("gen_ai.usage.output_tokens", value), do: {:usage, %{output: value}}
  defp map_attribute("gen_ai.usage.total_tokens", value), do: {:usage, %{total: value}}
  defp map_attribute("gen_ai.usage.prompt_tokens", value), do: {:usage, %{input: value}}
  defp map_attribute("gen_ai.usage.completion_tokens", value), do: {:usage, %{output: value}}
  defp map_attribute("gen_ai.usage.cost", value), do: {:cost, %{total: value}}

  defp map_attribute("llm.token_count.prompt", value), do: {:usage, %{input: value}}
  defp map_attribute("llm.token_count.completion", value), do: {:usage, %{output: value}}
  defp map_attribute("llm.token_count.total", value), do: {:usage, %{total: value}}

  defp map_attribute("gen_ai.request.temperature", value),
    do: {:model_parameters, %{temperature: value}}

  defp map_attribute("gen_ai.request.max_tokens", value),
    do: {:model_parameters, %{max_tokens: value}}

  defp map_attribute("gen_ai.request.top_p", value), do: {:model_parameters, %{top_p: value}}

  defp map_attribute("gen_ai.request.frequency_penalty", value),
    do: {:model_parameters, %{frequency_penalty: value}}

  defp map_attribute("gen_ai.request.presence_penalty", value),
    do: {:model_parameters, %{presence_penalty: value}}

  defp map_attribute("gen_ai.request.stop_sequences", value),
    do: {:model_parameters, %{stop: value}}

  defp map_attribute("gen_ai.request.seed", value), do: {:model_parameters, %{seed: value}}

  defp map_attribute("llm.invocation_parameters." <> param, value),
    do: {:model_parameters, %{param => value}}

  defp map_attribute("gen_ai.system", value), do: {:metadata, %{"gen_ai.system" => value}}
  defp map_attribute("gen_ai.operation.name", value), do: {:metadata, %{"operation" => value}}
  defp map_attribute("gen_ai.request.top_k", value), do: {:model_parameters, %{top_k: value}}

  defp map_attribute(_key, _value), do: nil

  defp parse_prompt_attribute(index_and_field) do
    case String.split(index_and_field, ".", parts: 2) do
      [index_str, field] ->
        case Integer.parse(index_str) do
          {index, ""} -> {index, field}
          _ -> nil
        end

      _ ->
        nil
    end
  end

  defp parse_json_or_string(value) when is_binary(value) do
    case Jason.decode(value) do
      {:ok, decoded} -> decoded
      {:error, _} -> value
    end
  end

  defp parse_json_or_string(value), do: value

  defp normalize_tags(tags) when is_list(tags), do: tags
  defp normalize_tags(tags) when is_binary(tags), do: String.split(tags, ",")
  defp normalize_tags(_), do: nil

  defp post_process(attrs) do
    attrs
    |> maybe_build_prompt_messages()
    |> maybe_build_completion_messages()
  end

  defp maybe_build_prompt_messages(%{prompt_messages: messages} = attrs) when is_map(messages) do
    sorted_messages =
      messages
      |> Enum.sort_by(fn {index, _} -> index end)
      |> Enum.map(fn {_, msg} -> msg end)

    attrs
    |> Map.delete(:prompt_messages)
    |> Map.put(:input, sorted_messages)
  end

  defp maybe_build_prompt_messages(attrs), do: attrs

  defp maybe_build_completion_messages(%{completion_messages: messages} = attrs)
       when is_map(messages) do
    sorted_messages =
      messages
      |> Enum.sort_by(fn {index, _} -> index end)
      |> Enum.map(fn {_, msg} -> msg end)

    attrs
    |> Map.delete(:completion_messages)
    |> Map.put(:output, sorted_messages)
  end

  defp maybe_build_completion_messages(attrs), do: attrs

  defp deep_merge(left, right) do
    Map.merge(left, right, fn
      _key, %{} = l, %{} = r -> deep_merge(l, r)
      _key, _l, r -> r
    end)
  end
end
