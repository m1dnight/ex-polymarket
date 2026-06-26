defmodule Polymarket.Supervisor do
  @moduledoc """
  Supervisor for the processes to communicate with Polymarket.
  """
  use Supervisor

  alias Polymarket.SocketSupervisor

  @spec start_link() :: Supervisor.on_start()
  def start_link do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      {DynamicSupervisor, name: SocketSupervisor, strategy: :one_for_one}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
