defmodule Polymarket.WebSocket.MessageHandler do
  @moduledoc """
  Pure functions to handle messages coming from the Polymarket websocket.
  """

  @spec handle_message(map(), Polymarket.WebSocket.t()) ::
          {:reply, {:text, String.t()}, Polymarket.WebSocket.t()}
          | {:noreply, Polymarket.WebSocket.t()}
  def handle_message(message, state) do
    case message do
      %{event_type: "new_market"} ->
        {:reply, {:text, subscribe_message(message.clob_token_ids)}, state}

      _ ->
        {:noreply, state}
    end
  end

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
end
