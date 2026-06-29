defmodule Polymarket.Schemas.ClobError do
  @moduledoc """
  A non-`200` error from a CLOB request, pairing the HTTP `status` with the
  server's message.

  Order rejections surface here — e.g. an unfunded wallet yields a `400` whose
  `error` describes the missing balance or allowance. `code` and
  `retry_after_seconds` are populated when the server provides them (e.g. post-only
  mode), otherwise `nil`.
  """

  use TypedStruct

  typedstruct do
    field(:status, non_neg_integer(), enforce: true)
    field(:error, String.t(), enforce: true)
    field(:code, String.t() | nil, default: nil)
    field(:retry_after_seconds, non_neg_integer() | nil, default: nil)
  end

  @doc """
  Builds a `ClobError` from an HTTP `status` and the (JSON-decoded) error `body`.

  A map body is read for the `error`/`code`/`retry_after_seconds` fields; any other
  body is stringified into `error` so nothing is lost.
  """
  @spec from_response(non_neg_integer(), term()) :: t()
  def from_response(status, body) when is_map(body) do
    %__MODULE__{
      status: status,
      error: fetch(body, :error, "unknown error"),
      code: fetch(body, :code, nil),
      retry_after_seconds: fetch(body, :retry_after_seconds, nil)
    }
  end

  def from_response(status, body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} when is_map(decoded) -> from_response(status, decoded)
      _other -> %__MODULE__{status: status, error: body}
    end
  end

  def from_response(status, body) do
    %__MODULE__{status: status, error: inspect(body)}
  end

  # Atom keys come from the JSON-to-atoms HTTP decode; string keys from a body we
  # decoded here. Try atom first, then string.
  @spec fetch(map(), atom(), term()) :: term()
  defp fetch(body, key, default) do
    case Map.fetch(body, key) do
      {:ok, value} -> value
      :error -> Map.get(body, Atom.to_string(key), default)
    end
  end
end
