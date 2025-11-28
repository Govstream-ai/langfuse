defmodule Langfuse.Session do
  @moduledoc """
  Group related traces into sessions.

  Sessions represent user conversations or interaction sequences. Traces
  with the same session ID are grouped together in the Langfuse dashboard,
  enabling analysis of multi-turn interactions.

  ## Creating Sessions

  Generate a session ID and use it across related traces:

      session_id = Langfuse.Session.new_id()

      trace1 = Langfuse.trace(name: "turn-1", session_id: session_id)
      trace2 = Langfuse.trace(name: "turn-2", session_id: session_id)

  Or create a session struct for local metadata:

      session = Langfuse.Session.start(metadata: %{user_agent: "mobile"})

      trace = Langfuse.trace(name: "request", session_id: session.id)

  ## Scoring Sessions

  Evaluate entire sessions with aggregate scores:

      Langfuse.Session.score(session_id,
        name: "satisfaction",
        value: 4.5,
        comment: "User completed goal"
      )

  ## Session IDs

  Session IDs are strings prefixed with "session_" followed by 24 hex
  characters. You can also use custom session IDs if preferred.

  """

  alias Langfuse.Score

  @typedoc "A unique session identifier string."
  @type session_id :: String.t()

  @typedoc """
  A session struct for local session management.

  The struct holds the session ID and optional metadata. The `:created_at`
  timestamp is set automatically when the session is started.
  """
  @type t :: %__MODULE__{
          id: session_id(),
          metadata: map() | nil,
          created_at: DateTime.t()
        }

  defstruct [:id, :metadata, :created_at]

  @doc """
  Generates a new unique session ID.

  ## Examples

      iex> session_id = Langfuse.Session.new_id()
      iex> String.starts_with?(session_id, "session_")
      true

  """
  @spec new_id() :: session_id()
  def new_id do
    "session_" <> generate_id()
  end

  @doc """
  Creates a new session struct.

  The session struct is a local convenience for managing session metadata.
  It is not sent to Langfuse; only the session ID is used when creating traces.

  ## Options

    * `:id` - Custom session ID. Auto-generated with `new_id/0` if not provided.
    * `:metadata` - Local metadata map for application use.

  ## Examples

      iex> session = Langfuse.Session.start()
      iex> String.starts_with?(session.id, "session_")
      true

      iex> session = Langfuse.Session.start(id: "custom-session")
      iex> session.id
      "custom-session"

      iex> session = Langfuse.Session.start(metadata: %{source: "api"})
      iex> session.metadata
      %{source: "api"}

  """
  @spec start(keyword()) :: t()
  def start(opts \\ []) do
    %__MODULE__{
      id: opts[:id] || new_id(),
      metadata: opts[:metadata],
      created_at: DateTime.utc_now()
    }
  end

  @doc """
  Returns the session ID from a session struct or string.

  Accepts either a `Langfuse.Session` struct or a session ID string,
  returning the ID in either case.

  ## Examples

      iex> session = Langfuse.Session.start(id: "sess-123")
      iex> Langfuse.Session.get_id(session)
      "sess-123"

      iex> Langfuse.Session.get_id("sess-456")
      "sess-456"

  """
  @spec get_id(t() | session_id()) :: session_id()
  def get_id(%__MODULE__{id: id}), do: id
  def get_id(id) when is_binary(id), do: id

  @doc """
  Attaches a score to a session.

  Session scores evaluate the entire session rather than individual
  traces or observations within it.

  ## Options

    * `:name` - Score name (required).
    * `:value` - Numeric value for numeric or boolean scores.
    * `:string_value` - String value for categorical scores.
    * `:data_type` - Score type: `:numeric`, `:categorical`, or `:boolean`.
      Auto-inferred if not provided.
    * `:comment` - Free-text comment or reasoning.
    * `:id` - Custom score ID for idempotent updates.
    * `:config_id` - Reference to a score configuration.

  ## Examples

      iex> Langfuse.Session.score("session-123", name: "satisfaction", value: 4.5)
      :ok

      iex> session = Langfuse.Session.start()
      iex> Langfuse.Session.score(session,
      ...>   name: "outcome",
      ...>   string_value: "converted",
      ...>   data_type: :categorical
      ...> )
      :ok

  """
  @spec score(t() | session_id(), keyword()) :: :ok | {:error, term()}
  def score(session, opts) do
    session_id = get_id(session)
    Score.score_session(session_id, opts)
  end

  defp generate_id do
    Base.encode16(:crypto.strong_rand_bytes(12), case: :lower)
  end
end
