defmodule Polymarket.Clob do
  @moduledoc """
  Client for the Polymarket CLOB REST API (https://clob.polymarket.com).

  The base URL defaults to production but can be pointed at another deployment —
  e.g. the staging host `https://clob-staging.polymarket.com` — with:

      config :ex_polymarket, :clob_url, "https://clob-staging.polymarket.com"

  Remember to match the chain id to the deployment when authenticating: `137`
  (Polygon) for production, `80002` (Amoy) for the testnet.
  """

  alias Polymarket.Clob.ClobAuth
  alias Polymarket.Clob.HmacAuth
  alias Polymarket.Clob.OrderPayload
  alias Polymarket.Crypto
  alias Polymarket.Http
  alias Polymarket.Schemas.ClobError
  alias Polymarket.Schemas.Credentials
  alias Polymarket.Schemas.MarketByToken
  alias Polymarket.Schemas.SendOrder
  alias Polymarket.Schemas.SendOrderResponse

  @default_url "https://clob.polymarket.com"

  @doc """
  Resolves a token ID to its parent market.

  Returns the market's `condition_id` and both token IDs for the given
  `token_id`. Useful when you have a token ID but not the condition ID.

  ## Examples

      Polymarket.Clob.get_market_by_token("71321045679252212594626385532706912750332728571942532289631379312455583992563")

  """
  @spec get_market_by_token(String.t()) ::
          {:ok, MarketByToken.t()} | {:error, :get_market_by_token_failed}
  def get_market_by_token(token_id) do
    with {:ok, raw} <- Http.get("#{base_url()}/markets-by-token/#{token_id}", [], __MODULE__),
         {:ok, market} <- MarketByToken.from_attrs(raw) do
      {:ok, market}
    else
      _err -> {:error, :get_market_by_token_failed}
    end
  end

  @doc """
  Derives this wallet's existing CLOB API credentials.

  Signs an L1 `ClobAuth` message with `private_key` (see `Polymarket.Clob.ClobAuth`)
  and calls `GET /auth/derive-api-key`, returning the deterministic credentials the
  CLOB has already associated with the wallet's address on `chain_id` (137 Polygon
  / 80002 Amoy).

  `opts` accepts `:nonce` (the API-key slot, default `0`) and `:timestamp` (Unix
  seconds, default the current system time).
  """
  @spec derive_api_key(Crypto.private_key(), integer(), keyword()) ::
          {:ok, Credentials.t()} | {:error, :derive_api_key_failed}
  def derive_api_key(private_key, chain_id, opts \\ []) do
    headers = auth_headers(private_key, chain_id, opts)

    with {:ok, raw} <- Http.get("#{base_url()}/auth/derive-api-key", [], __MODULE__, headers),
         {:ok, credentials} <- Credentials.from_attrs(raw) do
      {:ok, with_owner_address(credentials, private_key)}
    else
      _err -> {:error, :derive_api_key_failed}
    end
  end

  @doc """
  Creates new CLOB API credentials for this wallet.

  Signs an L1 `ClobAuth` message with `private_key` and calls
  `POST /auth/api-key`, returning freshly minted credentials. Accepts the same
  `opts` as `derive_api_key/3`.
  """
  @spec create_api_key(Crypto.private_key(), integer(), keyword()) ::
          {:ok, Credentials.t()} | {:error, :create_api_key_failed}
  def create_api_key(private_key, chain_id, opts \\ []) do
    headers = auth_headers(private_key, chain_id, opts)

    with {:ok, raw} <- Http.post("#{base_url()}/auth/api-key", "", __MODULE__, headers),
         {:ok, credentials} <- Credentials.from_attrs(raw) do
      {:ok, with_owner_address(credentials, private_key)}
    else
      _err -> {:error, :create_api_key_failed}
    end
  end

  @doc """
  Creates new credentials, falling back to deriving existing ones.

  Mirrors the reference client: tries `create_api_key/3` first and, if it fails
  (e.g. the wallet already has a key), returns `derive_api_key/3` instead. Accepts
  the same `opts` as those functions.
  """
  @spec create_or_derive_api_key(Crypto.private_key(), integer(), keyword()) ::
          {:ok, Credentials.t()} | {:error, :derive_api_key_failed}
  def create_or_derive_api_key(private_key, chain_id, opts \\ []) do
    case create_api_key(private_key, chain_id, opts) do
      {:ok, credentials} -> {:ok, credentials}
      {:error, _reason} -> derive_api_key(private_key, chain_id, opts)
    end
  end

  @doc """
  Submits a caller-constructed, already-signed order to `POST /order`.

  Takes a `Polymarket.Schemas.SendOrder` — the exact CLOB request payload, which the
  caller builds: sign the order with `Polymarket.Clob.OrderSigner`, fold the
  signature in, and set `owner`/`order_type`/flags. This function only serialises it,
  authenticates the request with L2 HMAC headers derived from `credentials`, and
  posts it.

  `credentials` must come from the auth functions (so its `address` — the api-key
  owner EOA — is populated); that address is sent as the `POLY_ADDRESS` header.
  Note this is the *signing* wallet, not the order's `maker`/`signer` (which, for a
  `:poly1271` deposit-wallet order, is the funder contract).

  `opts`: `:timestamp` (Unix seconds, default now) for the L2 signature.

  Returns `{:ok, %Polymarket.Schemas.SendOrderResponse{}}` on success, or
  `{:error, %Polymarket.Schemas.ClobError{}}` when the CLOB rejects the order (e.g.
  an unfunded wallet's insufficient-balance error).
  """
  @spec post_order(SendOrder.t(), Credentials.t(), keyword()) ::
          {:ok, SendOrderResponse.t()} | {:error, ClobError.t()}
  def post_order(%SendOrder{} = send_order, %Credentials{address: <<_::160>>} = credentials, opts \\ []) do
    body = OrderPayload.serialize(send_order)
    timestamp = Keyword.get(opts, :timestamp, System.os_time(:second))
    headers = HmacAuth.headers(credentials.address, credentials, "POST", "/order", body, timestamp)

    case Http.post("#{base_url()}/order", body, __MODULE__, headers) do
      {:ok, raw} -> {:ok, SendOrderResponse.from_attrs(raw)}
      {:error, {status, raw}} -> {:error, ClobError.from_response(status, raw)}
    end
  end

  @doc """
  Submits a batch of caller-constructed, already-signed orders to `POST /orders`.

  The batch form of `post_order/3`: takes a list of `Polymarket.Schemas.SendOrder`s
  (each built and signed exactly as for `post_order/3`), serialises them into one
  JSON array, authenticates the request with L2 HMAC headers from `credentials`, and
  posts it. The CLOB processes the orders in parallel and caps a batch at 15; that
  limit is enforced server-side (a `400` `ClobError` otherwise).

  `credentials` must come from the auth functions (so its `address` — the api-key
  owner EOA — is set for the `POLY_ADDRESS` header). `opts`: `:timestamp` (Unix
  seconds, default now) for the L2 signature.

  Returns `{:ok, [%Polymarket.Schemas.SendOrderResponse{}]}` — one entry per order,
  in request order, each with its own `success`/`status` — or
  `{:error, %Polymarket.Schemas.ClobError{}}` when the CLOB rejects the whole request
  (e.g. an empty or over-15 batch, or an auth failure).
  """
  @spec post_orders([SendOrder.t()], Credentials.t(), keyword()) ::
          {:ok, [SendOrderResponse.t()]} | {:error, ClobError.t()}
  def post_orders(send_orders, %Credentials{address: <<_::160>>} = credentials, opts \\ []) when is_list(send_orders) do
    body = OrderPayload.serialize_many(send_orders)
    timestamp = Keyword.get(opts, :timestamp, System.os_time(:second))
    headers = HmacAuth.headers(credentials.address, credentials, "POST", "/orders", body, timestamp)

    case Http.post("#{base_url()}/orders", body, __MODULE__, headers) do
      {:ok, raw} -> {:ok, raw |> List.wrap() |> Enum.map(&SendOrderResponse.from_attrs/1)}
      {:error, {status, raw}} -> {:error, ClobError.from_response(status, raw)}
    end
  end

  @doc """
  Returns the current server time as a Unix timestamp (seconds since the epoch).

  Useful for synchronising a local clock with the CLOB server before signing
  time-sensitive requests. The endpoint returns the timestamp as a bare value
  (a JSON string in practice) rather than an object; it is parsed into an integer.

  ## Examples

      Polymarket.Clob.get_server_time()
      #=> {:ok, 1234567890}

  """
  @spec get_server_time() :: {:ok, integer()} | {:error, :get_server_time_failed}
  def get_server_time do
    case Http.get("#{base_url()}/time", [], __MODULE__) do
      {:ok, time} -> parse_server_time(time)
      _err -> {:error, :get_server_time_failed}
    end
  end

  @doc """
  Returns the current server time as a UTC `DateTime`.

  Convenience wrapper around `get_server_time/0` that converts the Unix timestamp
  (seconds since the epoch) into a `DateTime` in the `Etc/UTC` time zone.

  ## Examples

      Polymarket.Clob.get_server_time_utc()
      #=> {:ok, ~U[2009-02-13 23:31:30Z]}

  """
  @spec get_server_time_utc() :: {:ok, DateTime.t()} | {:error, :get_server_time_failed}
  def get_server_time_utc do
    with {:ok, time} <- get_server_time(),
         {:ok, datetime} <- DateTime.from_unix(time) do
      {:ok, datetime}
    else
      _err -> {:error, :get_server_time_failed}
    end
  end

  # The CLOB base URL: production by default, overridable for staging/testnet.
  @spec base_url() :: String.t()
  defp base_url, do: Application.get_env(:ex_polymarket, :clob_url, @default_url)

  # Builds the L1 auth headers from `opts` (`:nonce` default 0, `:timestamp`
  # default the current system time in Unix seconds).
  @spec auth_headers(Crypto.private_key(), integer(), keyword()) :: [Http.header()]
  defp auth_headers(private_key, chain_id, opts) do
    nonce = Keyword.get(opts, :nonce, 0)
    timestamp = Keyword.get(opts, :timestamp, System.os_time(:second))
    ClobAuth.headers(private_key, timestamp, nonce, chain_id)
  end

  # Records the api-key owner's address on the credentials, for the L2
  # `POLY_ADDRESS` header. `from_attrs/1` can't know it (it's not in the JSON).
  @spec with_owner_address(Credentials.t(), Crypto.private_key()) :: Credentials.t()
  defp with_owner_address(credentials, private_key) do
    %{credentials | address: Crypto.address_from_private_key(private_key)}
  end

  # The endpoint returns the Unix timestamp as a string, though staging has been
  # seen to return a bare integer, so both are accepted.
  @spec parse_server_time(term()) :: {:ok, integer()} | {:error, :get_server_time_failed}
  defp parse_server_time(time) when is_integer(time), do: {:ok, time}

  defp parse_server_time(time) when is_binary(time) do
    case Integer.parse(time) do
      {seconds, ""} -> {:ok, seconds}
      _ -> {:error, :get_server_time_failed}
    end
  end

  defp parse_server_time(_time), do: {:error, :get_server_time_failed}
end
