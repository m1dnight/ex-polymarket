defmodule Polymarket.Clob.ClobAuth do
  @moduledoc """
  EIP-712 **L1** authentication for the Polymarket CLOB.

  Before a wallet can obtain API credentials it must prove control of its address
  by signing a fixed `ClobAuth` message. That signature — together with the
  address, nonce and timestamp — forms the *L1* header set the CLOB requires on
  `GET /auth/derive-api-key` and `POST /auth/api-key`.

  The signed typed data is:

      ClobAuth(address address,string timestamp,uint256 nonce,string message)

  where `message` is the constant
  `"This message attests that I control the given wallet"`, signed under the
  `ClobAuthDomain` (version `"1"`) domain, which — unlike the order domain — has
  **no** verifying contract.

  Unlike the L2 (HMAC) headers, the L1 signature covers only `(address, timestamp,
  nonce, chain_id)`; it does not depend on the request path or body.
  """

  alias Polymarket.Crypto
  alias Polymarket.Crypto.Eip712

  @domain_name "ClobAuthDomain"
  @domain_version "1"
  @message "This message attests that I control the given wallet"

  @clob_auth_type "ClobAuth(address address,string timestamp,uint256 nonce,string message)"

  @poly_address "POLY_ADDRESS"
  @poly_nonce "POLY_NONCE"
  @poly_signature "POLY_SIGNATURE"
  @poly_timestamp "POLY_TIMESTAMP"

  @doc """
  Computes the EIP-712 `hashStruct` of the `ClobAuth` message for `address`,
  `timestamp` (Unix seconds) and `nonce`.
  """
  @spec eip712_hash_struct(<<_::160>>, integer(), non_neg_integer()) :: <<_::256>>
  def eip712_hash_struct(<<_::160>> = address, timestamp, nonce) do
    Eip712.hash_struct(@clob_auth_type, [
      Eip712.encode_address(address),
      Eip712.encode_string(Integer.to_string(timestamp)),
      Eip712.encode_uint256(nonce),
      Eip712.encode_string(@message)
    ])
  end

  @doc """
  Computes the 32-byte EIP-712 signing digest for the `ClobAuth` message on
  `chain_id`.
  """
  @spec signing_digest(<<_::160>>, integer(), non_neg_integer(), integer()) :: <<_::256>>
  def signing_digest(<<_::160>> = address, timestamp, nonce, chain_id) do
    separator = Eip712.domain_separator(@domain_name, @domain_version, chain_id)
    Eip712.digest(separator, eip712_hash_struct(address, timestamp, nonce))
  end

  @doc """
  Signs the `ClobAuth` message with `private_key`, returning the `0x`-prefixed
  65-byte signature hex used in the `POLY_SIGNATURE` L1 header.
  """
  @spec sign(Crypto.private_key(), integer(), non_neg_integer(), integer()) :: String.t()
  def sign(<<_::256>> = private_key, timestamp, nonce, chain_id) do
    address = Crypto.address_from_private_key(private_key)
    digest = signing_digest(address, timestamp, nonce, chain_id)
    "0x" <> Base.encode16(Crypto.sign_digest(digest, private_key), case: :lower)
  end

  @doc """
  Builds the four **L1** authentication headers (`POLY_ADDRESS`, `POLY_NONCE`,
  `POLY_SIGNATURE`, `POLY_TIMESTAMP`) for `private_key` on `chain_id`.

  `timestamp` is Unix seconds and must match the value sent to the server; `nonce`
  selects the API-key slot (callers default it to `0`). The address is rendered as
  lowercase `0x` hex, as the CLOB expects for L1 (L2 instead uses the checksummed
  form).
  """
  @spec headers(Crypto.private_key(), integer(), non_neg_integer(), integer()) ::
          [{String.t(), String.t()}]
  def headers(<<_::256>> = private_key, timestamp, nonce, chain_id) do
    address = Crypto.address_from_private_key(private_key)

    [
      {@poly_address, "0x" <> Base.encode16(address, case: :lower)},
      {@poly_nonce, Integer.to_string(nonce)},
      {@poly_signature, sign(private_key, timestamp, nonce, chain_id)},
      {@poly_timestamp, Integer.to_string(timestamp)}
    ]
  end
end
