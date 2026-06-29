defmodule Polymarket.Schemas.Credentials do
  @moduledoc """
  Polymarket CLOB **API credentials**: the `api_key`, `secret` and `passphrase`
  returned by `GET /auth/derive-api-key` and `POST /auth/api-key`, plus the
  `address` of the EOA that owns them.

  These authorise the L2 (HMAC) headers on every authenticated CLOB request, so
  the `secret` and `passphrase` are sensitive. To avoid leaking them through logs
  or crash reports, only `api_key` and `address` are shown when inspected.

  `address` is the wallet that signed the L1 auth (the api-key owner) and is sent
  as the `POLY_ADDRESS` L2 header. `from_attrs/1` cannot know it — the
  `Polymarket.Clob` auth functions populate it from the signing key — so it is
  `nil` on a freshly parsed `Credentials`.
  """

  use TypedStruct

  alias Polymarket.JsonUtil

  # Redact the secret material: inspecting shows only api_key and the (public) address.
  @derive {Inspect, only: [:api_key, :address]}
  typedstruct do
    field(:api_key, String.t(), enforce: true)
    field(:secret, String.t(), enforce: true)
    field(:passphrase, String.t(), enforce: true)
    field(:address, <<_::160>> | nil, default: nil)
  end

  @doc """
  Builds a `Credentials` from the raw (JSON-decoded) attributes returned by the
  CLOB auth endpoints. Keys may be `camelCase` (e.g. `apiKey`); they are
  normalised to the struct's `snake_case` fields. Returns
  `{:error, :invalid_credentials}` if any of the three string fields is missing.
  """
  @spec from_attrs(map()) :: {:ok, t()} | {:error, :invalid_credentials}
  def from_attrs(attrs) when is_map(attrs) do
    normalized = JsonUtil.snake_case_keys(attrs)

    with {:ok, api_key} <- fetch_string(normalized, "api_key"),
         {:ok, secret} <- fetch_string(normalized, "secret"),
         {:ok, passphrase} <- fetch_string(normalized, "passphrase") do
      {:ok, %__MODULE__{api_key: api_key, secret: secret, passphrase: passphrase}}
    end
  end

  @spec fetch_string(map(), String.t()) :: {:ok, String.t()} | {:error, :invalid_credentials}
  defp fetch_string(map, key) do
    case Map.get(map, key) do
      value when is_binary(value) -> {:ok, value}
      _other -> {:error, :invalid_credentials}
    end
  end
end
