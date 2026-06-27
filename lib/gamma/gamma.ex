defmodule Polymarket.Gamma do
  @moduledoc """
  Client for the Polymarket Gamma REST API (https://gamma-api.polymarket.com).
  """

  alias Polymarket.Schemas.Market

  @url "https://gamma-api.polymarket.com"

  @typedoc """
  Query options forwarded to the Gamma API as query parameters.

    * `:include_tag` - when `true`, includes the market's `tags` in the response.
  """
  @type option :: {:include_tag, boolean()}
  @type options :: [option()]

  @doc """
  Retrieves a single market by its unique ID.

  Returns detailed information about a market.

  ## Options

  `opts` are sent verbatim as query parameters. The Gamma API supports:

    * `:include_tag` - when `true`, includes the market's `tags` in the response.

  ## Examples

      Polymarket.Gamma.get_market_by_id(2_691_932, include_tag: true)

  """
  @spec get_market_by_id(non_neg_integer() | String.t(), options()) ::
          {:ok, Market.t()} | {:error, :get_market_failed}
  def get_market_by_id(market_id, opts \\ []) do
    with {:ok, raw} <- get_request("#{@url}/markets/#{market_id}", opts),
         {:ok, market} <- Market.from_attrs(raw) do
      {:ok, market}
    else
      _err -> {:error, :get_market_failed}
    end
  end

  # ---------------------------------------------------------------------------#
  #                                Helpers                                     #
  # ---------------------------------------------------------------------------#

  @spec get_request(String.t(), keyword()) :: {:ok, term()} | {:error, :failed_to_get}
  defp get_request(url, params) do
    # Array-valued params (e.g. `clob_token_ids: ["1", "2"]`) become repeated
    # query params (`?clob_token_ids=1&clob_token_ids=2`); Req itself rejects
    # list values.
    params =
      Enum.flat_map(params, fn
        {key, values} when is_list(values) -> Enum.map(values, &{key, &1})
        pair -> [pair]
      end)

    options =
      [decode_json: [keys: :atoms], params: params]
      |> Keyword.merge(req_options())

    response = Req.get!(url, options)

    case response do
      %{status: 200, body: body} ->
        {:ok, body}

      _ ->
        {:error, :failed_to_get}
    end
  end

  # Extra options merged into every request, e.g. a `Req.Test` stub in tests.
  @spec req_options() :: keyword()
  defp req_options do
    Application.get_env(:ex_polymarket, :req_options, [])
  end
end
