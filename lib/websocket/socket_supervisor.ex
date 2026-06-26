defmodule Polymarket.WebSocket.SocketSupervisor do
  @moduledoc """
  Dynamic supervisor for all websocket connections to polymarket.

  A single websocket can only hold so many asset ids, so sharding is required to
  make sure we can subscribe to more assets than a single connection allows.
  """
  use DynamicSupervisor

  alias Polymarket.WebSocket
  # Automatically defines child_spec/1
  @spec start_link(term()) :: Supervisor.on_start()
  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @spec add_connection() :: DynamicSupervisor.on_start_child()
  def add_connection do
    DynamicSupervisor.start_child(Polymarket.SocketSupervisor, WebSocket)
  end
end
