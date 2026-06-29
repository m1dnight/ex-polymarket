defmodule Polymarket.Http do
  @moduledoc """
  Shared `Req`-based HTTP plumbing for the Polymarket API clients
  (`Polymarket.Gamma`, `Polymarket.Clob`).

  Each client passes itself as the `owner` so that, in tests, requests route
  through that client's own `Req.Test` stub (see `req_options/1`).
  """

  @typedoc "An HTTP header as a `{name, value}` pair."
  @type header :: {String.t(), String.t()}

  @doc """
  Issue a `GET` request and return the decoded JSON body on a `200` response.

  `params` are sent as query parameters; array-valued params are expanded into
  repeated keys (`clob_token_ids: ["1", "2"]` -> `?clob_token_ids=1&clob_token_ids=2`)
  since `Req` rejects list values. `headers` are extra request headers (e.g. the
  `POLY_*` authentication headers). `owner` is the calling client module, used to
  scope the `Req.Test` stub during tests.
  """
  @spec get(String.t(), keyword(), module(), [header()]) ::
          {:ok, term()} | {:error, :failed_to_get}
  def get(url, params, owner, headers \\ []) do
    expanded =
      Enum.flat_map(params, fn
        {key, values} when is_list(values) -> Enum.map(values, &{key, &1})
        pair -> [pair]
      end)

    options =
      [decode_json: [keys: :atoms], params: expanded, headers: headers]
      |> Keyword.merge(req_options(owner))

    case Req.get!(url, options) do
      %{status: 200, body: body} -> {:ok, body}
      _ -> {:error, :failed_to_get}
    end
  end

  @doc """
  Issue a `POST` request with a raw `body`, returning the decoded JSON body on a
  `2xx` response and `{:error, {status, body}}` otherwise.

  `body` is sent verbatim — callers that authenticate the request (L2 HMAC) must
  sign exactly these bytes, so the body is never re-encoded here. A
  `content-type: application/json` header is added for non-empty bodies. `headers`
  are extra request headers and `owner` scopes the `Req.Test` stub during tests.

  Unlike `get/4`, a non-2xx surfaces the status and decoded body so callers can
  report the server's error (e.g. an order rejection) rather than a bare atom. A
  transport failure (no HTTP response) is returned as `{:error, {0, message}}`
  rather than raised, so callers' `{:ok, _} | {:error, _}` contracts hold.
  """
  @spec post(String.t(), binary(), module(), [header()]) ::
          {:ok, term()} | {:error, {non_neg_integer(), term()}}
  def post(url, body, owner, headers \\ []) do
    options =
      [decode_json: [keys: :atoms], body: body, headers: content_type(body, headers)]
      |> Keyword.merge(req_options(owner))

    case Req.post(url, options) do
      {:ok, %{status: status, body: resp}} when status in 200..299 -> {:ok, resp}
      {:ok, %{status: status, body: resp}} -> {:error, {status, resp}}
      {:error, exception} -> {:error, {0, Exception.message(exception)}}
    end
  end

  # A JSON body needs its content type; an empty body (e.g. L1 `create_api_key`)
  # carries no content type.
  @spec content_type(binary(), [header()]) :: [header()]
  defp content_type("", headers), do: headers
  defp content_type(_body, headers), do: [{"content-type", "application/json"} | headers]

  # Base options from config, plus the per-owner `Req.Test` plug when testing.
  @spec req_options(module()) :: keyword()
  defp req_options(owner) do
    base = Application.get_env(:ex_polymarket, :req_options, [])

    if Application.get_env(:ex_polymarket, :http_test_mode, false) do
      Keyword.put(base, :plug, {Req.Test, owner})
    else
      base
    end
  end
end
