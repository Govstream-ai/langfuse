defmodule Langfuse.Test.Helpers do
  @moduledoc """
  Test helpers for applications using the Langfuse SDK.

  These utilities make it easier to test code that uses Langfuse tracing
  without sending data to the actual Langfuse API.

  ## Setup

  Add this module to your test environment by including it in your
  `test/test_helper.exs`:

      # test/test_helper.exs
      ExUnit.start()
      Langfuse.Test.Helpers.setup_test_mode()

  Or configure test mode in your `config/test.exs`:

      config :langfuse, enabled: false

  ## Capturing Events

  Use `capture_events/1` to test that your code creates the expected
  traces and observations:

      test "creates trace with spans" do
        {_result, events} = Langfuse.Test.Helpers.capture_events(fn ->
          trace = Langfuse.trace(name: "test")
          span = Langfuse.span(trace, name: "operation")
          Langfuse.end_observation(span)
        end)

        assert length(events) == 3
        assert Enum.any?(events, &(&1.type == "trace-create"))
      end

  """

  @doc """
  Configures Langfuse for test mode.

  Disables actual ingestion by setting `:enabled` to `false`.
  Call this in your `test_helper.exs` to disable Langfuse globally for tests.

  ## Examples

      # In test/test_helper.exs
      Langfuse.Test.Helpers.setup_test_mode()

  """
  @spec setup_test_mode() :: :ok
  def setup_test_mode do
    Application.put_env(:langfuse, :enabled, false)
    :ok
  end

  @doc """
  Temporarily enables test mode and restores previous setting.

  Useful for setup blocks in individual tests or describe blocks.

  ## Examples

      setup do
        Langfuse.Test.Helpers.with_test_mode()
      end

  """
  @spec with_test_mode() :: :ok
  def with_test_mode do
    previous = Application.get_env(:langfuse, :enabled, true)
    Application.put_env(:langfuse, :enabled, false)

    ExUnit.Callbacks.on_exit(fn ->
      Application.put_env(:langfuse, :enabled, previous)
    end)

    :ok
  end

  @doc """
  Captures all Langfuse events created within the given function.

  Temporarily enables event capture mode, executes the function,
  and returns both the function's result and the list of captured events.

  Events are captured in order of creation. Each event is a map with
  `:type`, `:timestamp`, `:id`, and `:body` keys.

  ## Examples

      {result, events} = Langfuse.Test.Helpers.capture_events(fn ->
        trace = Langfuse.trace(name: "my-trace")
        span = Langfuse.span(trace, name: "my-span")
        Langfuse.end_observation(span)
        :done
      end)

      assert result == :done
      assert length(events) == 3

      trace_event = Enum.find(events, &(&1.type == "trace-create"))
      assert trace_event.body.name == "my-trace"

  """
  @spec capture_events((-> result)) :: {result, [map()]} when result: term()
  def capture_events(fun) when is_function(fun, 0) do
    {:ok, agent} = Agent.start_link(fn -> [] end)

    previous_enabled = Application.get_env(:langfuse, :enabled, true)
    previous_handler = Application.get_env(:langfuse, :event_handler)

    Application.put_env(:langfuse, :enabled, true)

    Application.put_env(:langfuse, :event_handler, fn event ->
      Agent.update(agent, &[event | &1])
    end)

    try do
      result = fun.()
      events = Agent.get(agent, &Enum.reverse/1)
      {result, events}
    after
      Application.put_env(:langfuse, :enabled, previous_enabled)

      if previous_handler do
        Application.put_env(:langfuse, :event_handler, previous_handler)
      else
        Application.delete_env(:langfuse, :event_handler)
      end

      Agent.stop(agent)
    end
  end

  @doc """
  Creates a mock prompt for testing.

  Returns a `Langfuse.Prompt` struct that can be used in tests without
  fetching from the API.

  ## Options

    * `:name` - Prompt name (default: "test-prompt")
    * `:version` - Version number (default: 1)
    * `:type` - `:text` or `:chat` (default: `:text`)
    * `:prompt` - Template content (default: "Hello {{name}}")
    * `:config` - Configuration map (default: nil)
    * `:labels` - List of labels (default: [])
    * `:tags` - List of tags (default: [])

  ## Examples

      prompt = Langfuse.Test.Helpers.mock_prompt(name: "greeting")
      compiled = Langfuse.Prompt.compile(prompt, %{name: "Alice"})
      assert compiled == "Hello Alice"

      chat_prompt = Langfuse.Test.Helpers.mock_prompt(
        type: :chat,
        prompt: [%{"role" => "user", "content" => "Hi {{name}}"}]
      )

  """
  @spec mock_prompt(keyword()) :: Langfuse.Prompt.t()
  def mock_prompt(opts \\ []) do
    %Langfuse.Prompt{
      name: Keyword.get(opts, :name, "test-prompt"),
      version: Keyword.get(opts, :version, 1),
      type: Keyword.get(opts, :type, :text),
      prompt: Keyword.get(opts, :prompt, "Hello {{name}}"),
      config: Keyword.get(opts, :config),
      labels: Keyword.get(opts, :labels, []),
      tags: Keyword.get(opts, :tags, [])
    }
  end

  @doc """
  Creates a mock trace for testing span/generation creation.

  Returns a `Langfuse.Trace` struct that can be used as a parent
  for spans and generations in tests.

  ## Options

    * `:id` - Trace ID (default: auto-generated)
    * `:name` - Trace name (default: "test-trace")

  ## Examples

      trace = Langfuse.Test.Helpers.mock_trace()
      span = Langfuse.span(trace, name: "test-span")

  """
  @spec mock_trace(keyword()) :: Langfuse.Trace.t()
  def mock_trace(opts \\ []) do
    %Langfuse.Trace{
      id: Keyword.get(opts, :id, generate_id()),
      name: Keyword.get(opts, :name, "test-trace"),
      timestamp: DateTime.utc_now()
    }
  end

  @doc """
  Asserts that an event list contains an event matching the given criteria.

  ## Examples

      {_result, events} = capture_events(fn -> ... end)

      Langfuse.Test.Helpers.assert_event(events, type: "trace-create")
      Langfuse.Test.Helpers.assert_event(events, type: "span-create", body: %{name: "my-span"})

  """
  @spec assert_event([map()], keyword()) :: map() | no_return()
  def assert_event(events, criteria) do
    type = Keyword.get(criteria, :type)
    body_match = Keyword.get(criteria, :body, %{})

    event =
      Enum.find(events, fn event ->
        type_matches = is_nil(type) or event.type == type

        body_matches =
          Enum.all?(body_match, fn {key, value} ->
            Map.get(event.body, key) == value
          end)

        type_matches and body_matches
      end)

    if is_nil(event) do
      raise ExUnit.AssertionError,
        message: "Expected to find event matching #{inspect(criteria)} in #{inspect(events)}"
    end

    event
  end

  defp generate_id do
    Base.encode16(:crypto.strong_rand_bytes(12), case: :lower)
  end
end
