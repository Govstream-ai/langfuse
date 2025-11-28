defmodule Langfuse.Error do
  @moduledoc """
  Structured error types for the Langfuse SDK.

  These exceptions provide detailed error information for different
  failure scenarios. All errors implement the Exception behaviour
  with descriptive messages.

  ## Error Types

    * `Langfuse.Error.ConfigError` - Configuration errors
    * `Langfuse.Error.APIError` - HTTP API errors
    * `Langfuse.Error.ValidationError` - Input validation errors
    * `Langfuse.Error.PromptNotFoundError` - Prompt fetch failures

  ## Usage

  Errors are returned in `{:error, reason}` tuples or raised as exceptions:

      case Langfuse.Prompt.get("missing") do
        {:ok, prompt} -> prompt
        {:error, %Langfuse.Error.PromptNotFoundError{} = error} ->
          Logger.warning(Exception.message(error))
      end

  """

  defmodule ConfigError do
    @moduledoc """
    Raised when SDK configuration is invalid or missing.

    This error indicates required configuration like API keys are missing
    or have invalid values.

    ## Fields

      * `:key` - The configuration key that is invalid or missing
      * `:message` - Human-readable description of the error

    """
    defexception [:key, :message]

    @type t :: %__MODULE__{
            key: atom(),
            message: String.t()
          }

    @impl true
    def message(%{key: key, message: msg}) when not is_nil(msg) do
      "Langfuse configuration error for #{inspect(key)}: #{msg}"
    end

    def message(%{key: key}) do
      "Langfuse configuration error: missing required key #{inspect(key)}"
    end
  end

  defmodule APIError do
    @moduledoc """
    Raised when the Langfuse API returns an error response.

    This error wraps HTTP errors with status codes and response bodies.

    ## Fields

      * `:status` - HTTP status code
      * `:body` - Response body (may be decoded JSON or raw string)
      * `:path` - API endpoint path

    """
    defexception [:status, :body, :path]

    @type t :: %__MODULE__{
            status: integer(),
            body: term(),
            path: String.t() | nil
          }

    @impl true
    def message(%{status: status, body: body, path: path}) when not is_nil(path) do
      "Langfuse API error on #{path} (HTTP #{status}): #{inspect(body)}"
    end

    def message(%{status: status, body: body}) do
      "Langfuse API error (HTTP #{status}): #{inspect(body)}"
    end
  end

  defmodule ValidationError do
    @moduledoc """
    Raised when input validation fails.

    This error indicates a required field is missing or has an invalid value.

    ## Fields

      * `:field` - The field that failed validation
      * `:message` - Description of what's wrong
      * `:value` - The invalid value (if applicable)

    """
    defexception [:field, :message, :value]

    @type t :: %__MODULE__{
            field: atom() | String.t(),
            message: String.t(),
            value: term()
          }

    @impl true
    def message(%{field: field, message: msg, value: value}) when not is_nil(value) do
      "Validation error on #{field}: #{msg} (got: #{inspect(value)})"
    end

    def message(%{field: field, message: msg}) do
      "Validation error on #{field}: #{msg}"
    end
  end

  defmodule PromptNotFoundError do
    @moduledoc """
    Raised when a prompt cannot be found in Langfuse.

    This error includes details about which prompt was requested
    to aid in debugging missing or misconfigured prompts.

    ## Fields

      * `:name` - Prompt name that was requested
      * `:version` - Specific version requested (if any)
      * `:label` - Label requested (if any)

    """
    defexception [:name, :version, :label]

    @type t :: %__MODULE__{
            name: String.t(),
            version: pos_integer() | nil,
            label: String.t() | nil
          }

    @impl true
    def message(%{name: name, version: nil, label: nil}) do
      "Prompt '#{name}' not found"
    end

    def message(%{name: name, version: version, label: nil}) when not is_nil(version) do
      "Prompt '#{name}' version #{version} not found"
    end

    def message(%{name: name, version: nil, label: label}) when not is_nil(label) do
      "Prompt '#{name}' with label '#{label}' not found"
    end

    def message(%{name: name, version: version, label: label}) do
      "Prompt '#{name}' (label: #{label}, version: #{version}) not found"
    end
  end
end
