defmodule Langfuse.Client do
  @moduledoc """
  Direct access to the Langfuse REST API.

  This module provides functions for interacting with Langfuse management
  APIs that are not covered by the tracing SDK. Use this for datasets,
  score configurations, listing traces/sessions, and other administrative
  operations.

  ## Datasets

  Create and manage evaluation datasets:

      {:ok, dataset} = Langfuse.Client.create_dataset(name: "qa-eval")

      {:ok, item} = Langfuse.Client.create_dataset_item(
        dataset_name: "qa-eval",
        input: %{question: "What is Elixir?"},
        expected_output: %{answer: "A functional programming language"}
      )

  ## Dataset Runs

  Track evaluation runs against datasets:

      {:ok, run} = Langfuse.Client.create_dataset_run(
        name: "eval-2025-01",
        dataset_name: "qa-eval"
      )

      {:ok, _} = Langfuse.Client.create_dataset_run_item(
        run_name: "eval-2025-01",
        dataset_item_id: item["id"],
        trace_id: trace.id
      )

  ## Querying Data

  List and retrieve traces, sessions, and scores:

      {:ok, traces} = Langfuse.Client.list_traces(limit: 10, user_id: "user-123")
      {:ok, trace} = Langfuse.Client.get_trace("trace-id")
      {:ok, sessions} = Langfuse.Client.list_sessions(limit: 50)

  ## Score Configurations

  Manage score configurations:

      {:ok, config} = Langfuse.Client.create_score_config(
        name: "accuracy",
        data_type: "NUMERIC",
        min_value: 0,
        max_value: 1
      )

  """

  alias Langfuse.{Config, HTTP}

  @typedoc "API response result."
  @type response :: {:ok, map()} | {:ok, list(map())} | {:error, term()}

  @doc """
  Lists prompts.

  ## Options

    * `:limit` - Maximum number of results
    * `:page` - Page number for pagination
    * `:name` - Filter by prompt name
    * `:label` - Filter by label
    * `:tag` - Filter by tag

  """
  @spec list_prompts(keyword()) :: response()
  def list_prompts(opts \\ []) do
    params =
      build_pagination_params(opts)
      |> maybe_add_param(:name, opts[:name])
      |> maybe_add_param(:label, opts[:label])
      |> maybe_add_param(:tag, opts[:tag])

    get("/api/public/v2/prompts", params)
  end

  @doc """
  Creates a new prompt version.

  ## Options

    * `:name` - Prompt name (required)
    * `:prompt` - Prompt content (required). String for text, list of messages for chat.
    * `:type` - Prompt type: "text" or "chat" (default: "text")
    * `:labels` - List of labels (e.g., ["production", "latest"])
    * `:tags` - List of tags
    * `:config` - Configuration map (model parameters, etc.)

  ## Examples

      Langfuse.Client.create_prompt(
        name: "greeting",
        prompt: "Hello {{name}}!",
        labels: ["production"]
      )

      Langfuse.Client.create_prompt(
        name: "chat-assistant",
        type: "chat",
        prompt: [
          %{"role" => "system", "content" => "You are helpful."},
          %{"role" => "user", "content" => "{{question}}"}
        ]
      )

  """
  @spec create_prompt(keyword()) :: response()
  def create_prompt(opts) do
    body =
      %{
        name: Keyword.fetch!(opts, :name),
        prompt: Keyword.fetch!(opts, :prompt)
      }
      |> maybe_put(:type, opts[:type] || "text")
      |> maybe_put(:labels, opts[:labels])
      |> maybe_put(:tags, opts[:tags])
      |> maybe_put(:config, opts[:config])

    post("/api/public/v2/prompts", body)
  end

  @doc """
  Updates labels for a specific prompt version.

  ## Options

    * `:labels` - New list of labels for this version

  ## Examples

      Langfuse.Client.update_prompt_labels("my-prompt", 3, labels: ["production", "v3"])

  """
  @spec update_prompt_labels(String.t(), pos_integer(), keyword()) :: response()
  def update_prompt_labels(name, version, opts) do
    body = %{labels: Keyword.fetch!(opts, :labels)}
    patch("/api/public/v2/prompts/#{URI.encode(name)}/versions/#{version}", body)
  end

  @doc """
  Gets a dataset by name.
  """
  @spec get_dataset(String.t()) :: response()
  def get_dataset(name) do
    get("/api/public/v2/datasets/#{URI.encode(name)}")
  end

  @doc """
  Creates a new dataset.

  ## Options

    * `:name` - Dataset name (required)
    * `:description` - Dataset description
    * `:metadata` - Additional metadata

  """
  @spec create_dataset(keyword()) :: response()
  def create_dataset(opts) do
    body =
      %{
        name: Keyword.fetch!(opts, :name)
      }
      |> maybe_put(:description, opts[:description])
      |> maybe_put(:metadata, opts[:metadata])

    post("/api/public/v2/datasets", body)
  end

  @doc """
  Lists datasets.

  ## Options

    * `:limit` - Maximum number of results (default: 50)
    * `:page` - Page number for pagination

  """
  @spec list_datasets(keyword()) :: response()
  def list_datasets(opts \\ []) do
    params = build_pagination_params(opts)
    get("/api/public/v2/datasets", params)
  end

  @doc """
  Creates a dataset item.

  ## Options

    * `:dataset_name` - Dataset name (required)
    * `:input` - Input data (required)
    * `:expected_output` - Expected output data
    * `:metadata` - Additional metadata
    * `:source_trace_id` - Source trace ID
    * `:source_observation_id` - Source observation ID
    * `:status` - Item status

  """
  @spec create_dataset_item(keyword()) :: response()
  def create_dataset_item(opts) do
    body =
      %{
        datasetName: Keyword.fetch!(opts, :dataset_name),
        input: Keyword.fetch!(opts, :input)
      }
      |> maybe_put(:expectedOutput, opts[:expected_output])
      |> maybe_put(:metadata, opts[:metadata])
      |> maybe_put(:sourceTraceId, opts[:source_trace_id])
      |> maybe_put(:sourceObservationId, opts[:source_observation_id])
      |> maybe_put(:status, opts[:status])

    post("/api/public/v2/dataset-items", body)
  end

  @doc """
  Gets a dataset item by ID.
  """
  @spec get_dataset_item(String.t()) :: response()
  def get_dataset_item(id) do
    get("/api/public/v2/dataset-items/#{URI.encode(id)}")
  end

  @doc """
  Updates a dataset item.

  ## Options

    * `:input` - Updated input data
    * `:expected_output` - Updated expected output
    * `:metadata` - Updated metadata
    * `:status` - Updated status ("ACTIVE" or "ARCHIVED")

  """
  @spec update_dataset_item(String.t(), keyword()) :: response()
  def update_dataset_item(id, opts) do
    body =
      %{}
      |> maybe_put(:input, opts[:input])
      |> maybe_put(:expectedOutput, opts[:expected_output])
      |> maybe_put(:metadata, opts[:metadata])
      |> maybe_put(:status, opts[:status])

    patch("/api/public/v2/dataset-items/#{URI.encode(id)}", body)
  end

  @doc """
  Creates a dataset run.

  ## Options

    * `:name` - Run name (required)
    * `:dataset_name` - Dataset name (required)
    * `:description` - Run description
    * `:metadata` - Additional metadata

  """
  @spec create_dataset_run(keyword()) :: response()
  def create_dataset_run(opts) do
    body =
      %{
        name: Keyword.fetch!(opts, :name),
        datasetName: Keyword.fetch!(opts, :dataset_name)
      }
      |> maybe_put(:description, opts[:description])
      |> maybe_put(:metadata, opts[:metadata])

    post("/api/public/v2/dataset-runs", body)
  end

  @doc """
  Creates a dataset run item linking a trace to a dataset item.

  ## Options

    * `:run_name` - Run name (required)
    * `:run_description` - Run description
    * `:dataset_item_id` - Dataset item ID (required)
    * `:trace_id` - Trace ID (required)
    * `:observation_id` - Observation ID
    * `:metadata` - Additional metadata

  """
  @spec create_dataset_run_item(keyword()) :: response()
  def create_dataset_run_item(opts) do
    body =
      %{
        runName: Keyword.fetch!(opts, :run_name),
        datasetItemId: Keyword.fetch!(opts, :dataset_item_id),
        traceId: Keyword.fetch!(opts, :trace_id)
      }
      |> maybe_put(:runDescription, opts[:run_description])
      |> maybe_put(:observationId, opts[:observation_id])
      |> maybe_put(:metadata, opts[:metadata])

    post("/api/public/v2/dataset-run-items", body)
  end

  @doc """
  Gets a dataset run by name.
  """
  @spec get_dataset_run(String.t(), String.t()) :: response()
  def get_dataset_run(dataset_name, run_name) do
    get("/api/public/datasets/#{URI.encode(dataset_name)}/runs/#{URI.encode(run_name)}")
  end

  @doc """
  Lists runs for a dataset.

  ## Options

    * `:limit` - Maximum number of results
    * `:page` - Page number for pagination

  """
  @spec list_dataset_runs(String.t(), keyword()) :: response()
  def list_dataset_runs(dataset_name, opts \\ []) do
    params = build_pagination_params(opts)
    get("/api/public/datasets/#{URI.encode(dataset_name)}/runs", params)
  end

  @doc """
  Deletes a dataset run.

  This operation is irreversible. All run items will also be deleted.
  """
  @spec delete_dataset_run(String.t(), String.t()) :: :ok | {:error, term()}
  def delete_dataset_run(dataset_name, run_name) do
    delete("/api/public/datasets/#{URI.encode(dataset_name)}/runs/#{URI.encode(run_name)}")
  end

  @doc """
  Lists dataset items.

  ## Options

    * `:limit` - Maximum number of results
    * `:page` - Page number for pagination
    * `:dataset_name` - Filter by dataset name

  """
  @spec list_dataset_items(keyword()) :: response()
  def list_dataset_items(opts \\ []) do
    params =
      build_pagination_params(opts)
      |> maybe_add_param(:datasetName, opts[:dataset_name])

    get("/api/public/dataset-items", params)
  end

  @doc """
  Lists dataset run items.

  ## Options

    * `:limit` - Maximum number of results
    * `:page` - Page number for pagination
    * `:run_name` - Filter by run name
    * `:dataset_item_id` - Filter by dataset item ID

  """
  @spec list_dataset_run_items(keyword()) :: response()
  def list_dataset_run_items(opts \\ []) do
    params =
      build_pagination_params(opts)
      |> maybe_add_param(:runName, opts[:run_name])
      |> maybe_add_param(:datasetItemId, opts[:dataset_item_id])

    get("/api/public/dataset-run-items", params)
  end

  @doc """
  Lists score configurations.
  """
  @spec list_score_configs(keyword()) :: response()
  def list_score_configs(opts \\ []) do
    params = build_pagination_params(opts)
    get("/api/public/v2/score-configs", params)
  end

  @doc """
  Gets a score configuration by ID.
  """
  @spec get_score_config(String.t()) :: response()
  def get_score_config(id) do
    get("/api/public/v2/score-configs/#{URI.encode(id)}")
  end

  @doc """
  Creates a score configuration.

  ## Options

    * `:name` - Config name (required)
    * `:data_type` - One of "NUMERIC", "CATEGORICAL", "BOOLEAN" (required)
    * `:min_value` - Minimum value (for numeric)
    * `:max_value` - Maximum value (for numeric)
    * `:categories` - List of category maps (for categorical)
    * `:description` - Config description

  """
  @spec create_score_config(keyword()) :: response()
  def create_score_config(opts) do
    body =
      %{
        name: Keyword.fetch!(opts, :name),
        dataType: Keyword.fetch!(opts, :data_type)
      }
      |> maybe_put(:minValue, opts[:min_value])
      |> maybe_put(:maxValue, opts[:max_value])
      |> maybe_put(:categories, opts[:categories])
      |> maybe_put(:description, opts[:description])

    post("/api/public/v2/score-configs", body)
  end

  @doc """
  Gets an observation by ID.

  Observations include spans, generations, and events within a trace.
  """
  @spec get_observation(String.t()) :: response()
  def get_observation(id) do
    get("/api/public/observations/#{URI.encode(id)}")
  end

  @doc """
  Lists observations.

  ## Options

    * `:limit` - Maximum number of results
    * `:page` - Page number
    * `:trace_id` - Filter by trace ID
    * `:name` - Filter by observation name
    * `:type` - Filter by type ("SPAN", "GENERATION", "EVENT")
    * `:user_id` - Filter by user ID
    * `:parent_observation_id` - Filter by parent observation

  """
  @spec list_observations(keyword()) :: response()
  def list_observations(opts \\ []) do
    params =
      build_pagination_params(opts)
      |> maybe_add_param(:traceId, opts[:trace_id])
      |> maybe_add_param(:name, opts[:name])
      |> maybe_add_param(:type, opts[:type])
      |> maybe_add_param(:userId, opts[:user_id])
      |> maybe_add_param(:parentObservationId, opts[:parent_observation_id])

    get("/api/public/observations", params)
  end

  @doc """
  Gets a trace by ID.
  """
  @spec get_trace(String.t()) :: response()
  def get_trace(id) do
    get("/api/public/traces/#{URI.encode(id)}")
  end

  @doc """
  Lists traces.

  ## Options

    * `:limit` - Maximum number of results
    * `:page` - Page number
    * `:user_id` - Filter by user ID
    * `:session_id` - Filter by session ID
    * `:name` - Filter by name
    * `:tags` - Filter by tags
    * `:from_timestamp` - Filter from timestamp
    * `:to_timestamp` - Filter to timestamp

  """
  @spec list_traces(keyword()) :: response()
  def list_traces(opts \\ []) do
    params =
      build_pagination_params(opts)
      |> maybe_add_param(:userId, opts[:user_id])
      |> maybe_add_param(:sessionId, opts[:session_id])
      |> maybe_add_param(:name, opts[:name])
      |> maybe_add_param(:tags, opts[:tags])
      |> maybe_add_param(:fromTimestamp, opts[:from_timestamp])
      |> maybe_add_param(:toTimestamp, opts[:to_timestamp])

    get("/api/public/traces", params)
  end

  @doc """
  Gets a session by ID.
  """
  @spec get_session(String.t()) :: response()
  def get_session(id) do
    get("/api/public/sessions/#{URI.encode(id)}")
  end

  @doc """
  Lists sessions.

  ## Options

    * `:limit` - Maximum number of results
    * `:page` - Page number
    * `:from_timestamp` - Filter from timestamp
    * `:to_timestamp` - Filter to timestamp

  """
  @spec list_sessions(keyword()) :: response()
  def list_sessions(opts \\ []) do
    params =
      build_pagination_params(opts)
      |> maybe_add_param(:fromTimestamp, opts[:from_timestamp])
      |> maybe_add_param(:toTimestamp, opts[:to_timestamp])

    get("/api/public/sessions", params)
  end

  @doc """
  Gets a score by ID.
  """
  @spec get_score(String.t()) :: response()
  def get_score(id) do
    get("/api/public/scores/#{URI.encode(id)}")
  end

  @doc """
  Lists scores.

  ## Options

    * `:limit` - Maximum number of results
    * `:page` - Page number
    * `:trace_id` - Filter by trace ID
    * `:user_id` - Filter by user ID
    * `:name` - Filter by score name
    * `:data_type` - Filter by data type

  """
  @spec list_scores(keyword()) :: response()
  def list_scores(opts \\ []) do
    params =
      build_pagination_params(opts)
      |> maybe_add_param(:traceId, opts[:trace_id])
      |> maybe_add_param(:userId, opts[:user_id])
      |> maybe_add_param(:name, opts[:name])
      |> maybe_add_param(:dataType, opts[:data_type])

    get("/api/public/scores", params)
  end

  @doc """
  Deletes a score by ID.
  """
  @spec delete_score(String.t()) :: :ok | {:error, term()}
  def delete_score(id) do
    delete("/api/public/scores/#{URI.encode(id)}")
  end

  @doc """
  Deletes a dataset by name.

  This operation is irreversible. All items and runs in the dataset
  will also be deleted.
  """
  @spec delete_dataset(String.t()) :: :ok | {:error, term()}
  def delete_dataset(name) do
    delete("/api/public/v2/datasets/#{URI.encode(name)}")
  end

  @doc """
  Deletes a dataset item by ID.
  """
  @spec delete_dataset_item(String.t()) :: :ok | {:error, term()}
  def delete_dataset_item(id) do
    delete("/api/public/v2/dataset-items/#{URI.encode(id)}")
  end

  @doc """
  Lists available models with pricing information.

  ## Options

    * `:limit` - Maximum number of results
    * `:page` - Page number

  """
  @spec list_models(keyword()) :: response()
  def list_models(opts \\ []) do
    params = build_pagination_params(opts)
    get("/api/public/models", params)
  end

  @doc """
  Gets a model by ID.
  """
  @spec get_model(String.t()) :: response()
  def get_model(id) do
    get("/api/public/models/#{URI.encode(id)}")
  end

  @doc """
  Creates a custom model definition.

  Custom models allow you to define pricing for models not in Langfuse's
  default model list, enabling accurate cost tracking.

  ## Options

    * `:model_name` - Model identifier (required). Must match what's sent in generations.
    * `:match_pattern` - Regex pattern for matching model names (required).
    * `:input_price` - Price per input token in USD (required).
    * `:output_price` - Price per output token in USD (required).
    * `:total_price` - Fixed price per request (optional, alternative to token pricing).
    * `:unit` - Pricing unit: "TOKENS", "CHARACTERS", "IMAGES", etc. (default: "TOKENS")
    * `:tokenizer_id` - Tokenizer to use for token counting.
    * `:tokenizer_config` - Tokenizer configuration map.

  ## Examples

      Langfuse.Client.create_model(
        model_name: "my-custom-model",
        match_pattern: "my-custom-.*",
        input_price: 0.0001,
        output_price: 0.0002,
        unit: "TOKENS"
      )

  """
  @spec create_model(keyword()) :: response()
  def create_model(opts) do
    body =
      %{
        modelName: Keyword.fetch!(opts, :model_name),
        matchPattern: Keyword.fetch!(opts, :match_pattern),
        inputPrice: Keyword.fetch!(opts, :input_price),
        outputPrice: Keyword.fetch!(opts, :output_price)
      }
      |> maybe_put(:totalPrice, opts[:total_price])
      |> maybe_put(:unit, opts[:unit])
      |> maybe_put(:tokenizerId, opts[:tokenizer_id])
      |> maybe_put(:tokenizerConfig, opts[:tokenizer_config])

    post("/api/public/models", body)
  end

  @doc """
  Deletes a custom model definition.

  Only custom models created via the API can be deleted.
  Built-in models cannot be deleted.
  """
  @spec delete_model(String.t()) :: :ok | {:error, term()}
  def delete_model(id) do
    delete("/api/public/models/#{URI.encode(id)}")
  end

  @doc """
  Makes a raw GET request to the Langfuse API.
  """
  @spec get(String.t(), keyword()) :: response()
  def get(path, params \\ []) do
    HTTP.get(path, params)
  end

  @doc """
  Makes a raw POST request to the Langfuse API.
  """
  @spec post(String.t(), map()) :: response()
  def post(path, body) do
    HTTP.post(path, body)
  end

  @doc """
  Makes a raw DELETE request to the Langfuse API.
  """
  @spec delete(String.t()) :: :ok | {:error, term()}
  def delete(path) do
    config = Config.get()

    unless Config.configured?() do
      {:error, :not_configured}
    else
      url = config.host <> path

      case Req.delete(url, auth: {:basic, "#{config.public_key}:#{config.secret_key}"}) do
        {:ok, %Req.Response{status: status}} when status in 200..299 ->
          :ok

        {:ok, %Req.Response{status: status, body: body}} ->
          {:error, %{status: status, body: body}}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  @doc """
  Makes a raw PATCH request to the Langfuse API.
  """
  @spec patch(String.t(), map()) :: response()
  def patch(path, body) do
    config = Config.get()

    unless Config.configured?() do
      {:error, :not_configured}
    else
      url = config.host <> path

      case Req.patch(url,
             json: body,
             auth: {:basic, "#{config.public_key}:#{config.secret_key}"}
           ) do
        {:ok, %Req.Response{status: status, body: resp_body}} when status in 200..299 ->
          {:ok, resp_body}

        {:ok, %Req.Response{status: status, body: resp_body}} ->
          {:error, %{status: status, body: resp_body}}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp build_pagination_params(opts) do
    []
    |> maybe_add_param(:limit, opts[:limit])
    |> maybe_add_param(:page, opts[:page])
  end

  defp maybe_add_param(params, _key, nil), do: params
  defp maybe_add_param(params, key, value), do: Keyword.put(params, key, value)

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
