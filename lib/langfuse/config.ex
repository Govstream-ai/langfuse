defmodule Langfuse.Config do
  @moduledoc """
  Configuration management for Langfuse SDK.

  ## Configuration Options

      config :langfuse,
        public_key: "pk-...",
        secret_key: "sk-...",
        host: "https://cloud.langfuse.com",
        flush_interval: 5_000,
        batch_size: 100,
        max_retries: 3,
        enabled: true

  ## Environment Variables

  Configuration can also be set via environment variables:

    - `LANGFUSE_PUBLIC_KEY`
    - `LANGFUSE_SECRET_KEY`
    - `LANGFUSE_HOST`

  Environment variables take precedence over application config.
  """

  use GenServer

  @default_host "https://cloud.langfuse.com"
  @default_flush_interval 5_000
  @default_batch_size 100
  @default_max_retries 3

  defstruct [
    :public_key,
    :secret_key,
    :host,
    :flush_interval,
    :batch_size,
    :max_retries,
    :enabled
  ]

  @type t :: %__MODULE__{
          public_key: String.t() | nil,
          secret_key: String.t() | nil,
          host: String.t(),
          flush_interval: pos_integer(),
          batch_size: pos_integer(),
          max_retries: non_neg_integer(),
          enabled: boolean()
        }

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec get() :: t()
  def get do
    GenServer.call(__MODULE__, :get)
  end

  @spec get(atom()) :: term()
  def get(key) when is_atom(key) do
    config = get()
    Map.get(config, key)
  end

  @spec enabled?() :: boolean()
  def enabled? do
    get(:enabled)
  end

  @spec configured?() :: boolean()
  def configured? do
    config = get()
    not is_nil(config.public_key) and not is_nil(config.secret_key)
  end

  @impl true
  def init(_opts) do
    config = load_config()
    {:ok, config}
  end

  @impl true
  def handle_call(:get, _from, config) do
    {:reply, config, config}
  end

  defp load_config do
    %__MODULE__{
      public_key: get_value(:public_key, "LANGFUSE_PUBLIC_KEY"),
      secret_key: get_value(:secret_key, "LANGFUSE_SECRET_KEY"),
      host: get_value(:host, "LANGFUSE_HOST") || @default_host,
      flush_interval: get_integer(:flush_interval) || @default_flush_interval,
      batch_size: get_integer(:batch_size) || @default_batch_size,
      max_retries: get_integer(:max_retries) || @default_max_retries,
      enabled: get_boolean(:enabled, true)
    }
  end

  defp get_value(key, env_var) do
    System.get_env(env_var) || Application.get_env(:langfuse, key)
  end

  defp get_integer(key) do
    case Application.get_env(:langfuse, key) do
      nil -> nil
      val when is_integer(val) -> val
      val when is_binary(val) -> String.to_integer(val)
    end
  end

  defp get_boolean(key, default) do
    case Application.get_env(:langfuse, key) do
      nil -> default
      val when is_boolean(val) -> val
      "true" -> true
      "false" -> false
      _ -> default
    end
  end
end
