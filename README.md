# Langfuse

[![Hex.pm](https://img.shields.io/hexpm/v/langfuse.svg)](https://hex.pm/packages/langfuse)
[![Docs](https://img.shields.io/badge/hex-docs-blue.svg)](https://hexdocs.pm/langfuse)

Community Elixir SDK for [Langfuse](https://langfuse.com) - Open source LLM observability, tracing, and prompt management.

> **Note**: This is an unofficial community-maintained SDK, not affiliated with or endorsed by Langfuse GmbH.

## Installation

Add `langfuse` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:langfuse, "~> 0.1.0"}
  ]
end
```

## Configuration

Configure Langfuse in your `config/config.exs`:

```elixir
config :langfuse,
  public_key: "pk-...",
  secret_key: "sk-...",
  host: "https://cloud.langfuse.com"  # optional, defaults to cloud
```

Or use environment variables:

```bash
export LANGFUSE_PUBLIC_KEY="pk-..."
export LANGFUSE_SECRET_KEY="sk-..."
export LANGFUSE_HOST="https://cloud.langfuse.com"
```

### Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `public_key` | string | - | Langfuse public key |
| `secret_key` | string | - | Langfuse secret key |
| `host` | string | `https://cloud.langfuse.com` | Langfuse API host |
| `flush_interval` | integer | `5000` | Batch flush interval in ms |
| `batch_size` | integer | `100` | Maximum events per batch |
| `max_retries` | integer | `3` | HTTP retry attempts |
| `enabled` | boolean | `true` | Enable/disable SDK |

## Quick Start

### Tracing

```elixir
# Create a trace
trace = Langfuse.trace(name: "chat-request", user_id: "user-123")

# Add a span for a retrieval step
span = Langfuse.span(trace, name: "document-retrieval", input: %{query: "test"})
# ... do retrieval work ...
span = Langfuse.update(span, output: retrieved_docs)
span = Langfuse.end_observation(span)

# Add a generation for the LLM call
generation = Langfuse.generation(trace,
  name: "chat-completion",
  model: "gpt-4",
  input: [%{role: "user", content: "Hello"}],
  model_parameters: %{temperature: 0.7}
)

# After receiving the response
generation = Langfuse.update(generation,
  output: %{role: "assistant", content: "Hi there!"},
  usage: %{input: 10, output: 5, total: 15}
)
generation = Langfuse.end_observation(generation)

# Score the trace
Langfuse.score(trace, name: "quality", value: 0.9)
```

### Sessions

Group related traces into sessions:

```elixir
# Generate a session ID
session_id = Langfuse.Session.new_id()

# Use session ID across multiple traces
trace1 = Langfuse.trace(name: "turn-1", session_id: session_id)
trace2 = Langfuse.trace(name: "turn-2", session_id: session_id)

# Score the entire session
Langfuse.Session.score(session_id, name: "satisfaction", value: 4.5)
```

### Prompts

Fetch and use prompts from Langfuse:

```elixir
# Fetch a prompt
{:ok, prompt} = Langfuse.Prompt.get("my-prompt")

# Fetch specific version or label
{:ok, prompt} = Langfuse.Prompt.get("my-prompt", version: 2)
{:ok, prompt} = Langfuse.Prompt.get("my-prompt", label: "production")

# Compile with variables
compiled = Langfuse.Prompt.compile(prompt, %{name: "Alice", topic: "weather"})

# Link prompt to generation
generation = Langfuse.generation(trace,
  name: "chat",
  prompt_name: prompt.name,
  prompt_version: prompt.version,
  input: compiled
)
```

### Scores

Score traces, observations, or sessions:

```elixir
# Numeric score
Langfuse.score(trace, name: "quality", value: 0.85)

# Categorical score
Langfuse.score(trace, name: "sentiment", string_value: "positive", data_type: :categorical)

# Boolean score
Langfuse.score(trace, name: "hallucination", value: false, data_type: :boolean)

# Score with comment
Langfuse.score(trace, name: "feedback", value: 5, comment: "Excellent response")
```

### Client API

Direct access to Langfuse REST API:

```elixir
# Datasets
{:ok, dataset} = Langfuse.Client.create_dataset(name: "my-dataset")
{:ok, item} = Langfuse.Client.create_dataset_item(
  dataset_name: "my-dataset",
  input: %{query: "test"},
  expected_output: %{answer: "response"}
)

# List traces
{:ok, traces} = Langfuse.Client.list_traces(limit: 10, user_id: "user-123")

# Score configurations
{:ok, config} = Langfuse.Client.create_score_config(
  name: "quality",
  data_type: "NUMERIC",
  min_value: 0,
  max_value: 1
)
```

## Telemetry

The SDK emits telemetry events for observability:

```elixir
# Attach a handler
:telemetry.attach(
  "langfuse-logger",
  [:langfuse, :http, :request, :stop],
  fn event, measurements, metadata, _config ->
    duration_ms = System.convert_time_unit(measurements.duration, :native, :millisecond)
    Logger.info("Langfuse HTTP #{metadata.method} #{metadata.path} took #{duration_ms}ms")
  end,
  nil
)

# Or use the built-in debug logger
Langfuse.Telemetry.attach_default_logger()
```

See `Langfuse.Telemetry` for all available events.

## Graceful Shutdown

The SDK automatically flushes pending events on application shutdown. For explicit control:

```elixir
# Flush all pending events (blocks until complete)
Langfuse.flush()

# Flush with timeout
Langfuse.flush(timeout: 10_000)

# Graceful shutdown
Langfuse.shutdown()
```

## License

MIT License - see [LICENSE](LICENSE) for details.
