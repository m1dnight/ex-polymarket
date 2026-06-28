defmodule Polymarket.Clob do
  @moduledoc """
  Client for the Polymarket CLOB REST API (https://clob.polymarket.com).
  """

  alias Polymarket.Http
  alias Polymarket.Schemas.MarketByToken

  @url "https://clob.polymarket.com"

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
    with {:ok, raw} <- Http.get("#{@url}/markets-by-token/#{token_id}", [], __MODULE__),
         {:ok, market} <- MarketByToken.from_attrs(raw) do
      {:ok, market}
    else
      _err -> {:error, :get_market_by_token_failed}
    end
  end
end
