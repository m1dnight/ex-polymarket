defmodule Polymarket.Http do
  @moduledoc """
  Shared `Req`-based HTTP plumbing for the Polymarket API clients
  (`Polymarket.Gamma`, `Polymarket.Clob`).

  Each client passes itself as the `owner` so that, in tests, requests route
  through that client's own `Req.Test` stub (see `req_options/1`).
  """

  @doc """
  Issue a `GET` request and return the decoded JSON body on a `200` response.

  `params` are sent as query parameters; array-valued params are expanded into
  repeated keys (`clob_token_ids: ["1", "2"]` -> `?clob_token_ids=1&clob_token_ids=2`)
  since `Req` rejects list values. `owner` is the calling client module, used to
  scope the `Req.Test` stub during tests.
  """
  @spec get(String.t(), keyword(), module()) :: {:ok, term()} | {:error, :failed_to_get}
  def get(url, params, owner) do
    expanded =
      Enum.flat_map(params, fn
        {key, values} when is_list(values) -> Enum.map(values, &{key, &1})
        pair -> [pair]
      end)

    options =
      [decode_json: [keys: :atoms], params: expanded]
      |> Keyword.merge(req_options(owner))

    case Req.get!(url, options) do
      %{status: 200, body: body} -> {:ok, body}
      _ -> {:error, :failed_to_get}
    end
  end

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
