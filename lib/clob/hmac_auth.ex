defmodule Polymarket.Clob.HmacAuth do
  @moduledoc """
  Polymarket CLOB **L2** (HMAC) authentication.

  Once a wallet holds API credentials (`Polymarket.Schemas.Credentials`, obtained
  via the L1 flow in `Polymarket.Clob.ClobAuth`), every authenticated request is
  signed with an HMAC-SHA256 over `"{timestamp}{METHOD}{path}{body}"`, keyed by the
  base64url-decoded `secret`. The resulting headers prove the request came from the
  credential holder.

  Headers produced: `POLY_ADDRESS` (EIP-55 checksummed), `POLY_API_KEY`,
  `POLY_PASSPHRASE`, `POLY_SIGNATURE`, `POLY_TIMESTAMP`.
  """

  alias Polymarket.Crypto
  alias Polymarket.Schemas.Credentials

  @poly_address "POLY_ADDRESS"
  @poly_api_key "POLY_API_KEY"
  @poly_passphrase "POLY_PASSPHRASE"
  @poly_signature "POLY_SIGNATURE"
  @poly_timestamp "POLY_TIMESTAMP"

  @doc """
  Computes the base64url HMAC-SHA256 signature for the L2 `message`.

  `message` is `"{timestamp}{method}{path}{body}"`. `secret` is the base64url API
  secret, decoded to form the HMAC key exactly as the server does.
  """
  @spec sign(String.t(), String.t()) :: String.t()
  def sign(secret, message) do
    key = Base.url_decode64!(secret, padding: true)
    Base.url_encode64(:crypto.mac(:hmac, :sha256, key, message), padding: true)
  end

  @doc """
  Builds the five L2 headers authenticating a `method` request to `path` carrying
  `body` at `timestamp` (Unix seconds), for the wallet `address` and `credentials`.

  `body` must be the exact bytes sent on the wire — the HMAC covers it verbatim
  (single quotes are normalised to double quotes, mirroring the reference client).
  """
  @spec headers(<<_::160>>, Credentials.t(), String.t(), String.t(), binary(), integer()) ::
          [{String.t(), String.t()}]
  def headers(<<_::160>> = address, %Credentials{} = credentials, method, path, body, timestamp) do
    message = "#{timestamp}#{method}#{path}#{normalize_body(body)}"

    [
      {@poly_address, Crypto.to_checksum_address(address)},
      {@poly_api_key, credentials.api_key},
      {@poly_passphrase, credentials.passphrase},
      {@poly_signature, sign(credentials.secret, message)},
      {@poly_timestamp, Integer.to_string(timestamp)}
    ]
  end

  @spec normalize_body(binary()) :: binary()
  defp normalize_body(body), do: String.replace(body, "'", "\"")
end
