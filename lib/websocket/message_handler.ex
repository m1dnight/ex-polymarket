defmodule Polymarket.WebSocket.MessageHandler do
  @moduledoc """
  Pure functions to handle messages coming from the Polymarket websocket.
  """

  alias Polymarket.Schemas.BestBidAskEvent
  alias Polymarket.Schemas.BookEvent
  alias Polymarket.Schemas.LastTradePriceEvent
  alias Polymarket.Schemas.MarketResolvedEvent
  alias Polymarket.Schemas.NewMarketEvent
  alias Polymarket.Schemas.PriceChangeEvent
  alias Polymarket.Schemas.TickSizeChangeEvent

  require Logger

  @doc """
  Handles an event from the websocket.

  Decodes the event into a struct if possible. Prints a warning if the event is undecodable.
  """
  @spec handle_message(map(), Polymarket.WebSocket.t()) ::
          {:reply, {:text, String.t()}, Polymarket.WebSocket.t()}
          | {:noreply, Polymarket.WebSocket.t()}

  def handle_message(message, state) do
    case decode_event(message) do
      {:ok, %NewMarketEvent{clob_token_ids: assets_ids}} ->
        {:reply, {:text, subscribe_message(assets_ids)}, state}

      {:ok, _event} ->
        {:noreply, state}

      {:error, _} ->
        Logger.warning("Failed to decode #{inspect(message)}")
        {:noreply, state}
    end
  end

  @spec subscribe_message([String.t()]) :: String.t()
  defp subscribe_message(asset_ids) do
    %{
      operation: "subscribe",
      assets_ids: asset_ids,
      custom_feature_enabled: true,
      level: 2,
      initial_dump: true
    }
    |> Jason.encode!()
  end

  @spec decode_event(map()) ::
          {:ok,
           NewMarketEvent.t()
           | BestBidAskEvent.t()
           | PriceChangeEvent.t()
           | BookEvent.t()
           | MarketResolvedEvent.t()
           | LastTradePriceEvent.t()
           | TickSizeChangeEvent.t()}
          | {:error, Ecto.Changeset.t() | :unknown_message}
  defp decode_event(message) do
    case message do
      %{event_type: "new_market"} ->
        NewMarketEvent.from_attrs(message)

      %{event_type: "best_bid_ask"} ->
        BestBidAskEvent.from_attrs(message)

      %{event_type: "price_change"} ->
        PriceChangeEvent.from_attrs(message)

      %{event_type: "book"} ->
        BookEvent.from_attrs(message)

      %{event_type: "market_resolved"} ->
        MarketResolvedEvent.from_attrs(message)

      %{event_type: "last_trade_price"} ->
        LastTradePriceEvent.from_attrs(message)

      %{event_type: "tick_size_change"} ->
        TickSizeChangeEvent.from_attrs(message)

      _ ->
        {:error, :unknown_message}
    end
  end
end
