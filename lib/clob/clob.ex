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
    case Http.get("#{@url}/time", [], __MODULE__) do
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
