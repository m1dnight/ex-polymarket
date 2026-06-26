defmodule Polymarket.WebSocket do
  @moduledoc """
  A WebSocket client for the Polymarket CLOB market feed.

  Wraps `Mint.WebSocket` in a `GenServer`, handling the HTTP upgrade,
  periodic pings, and decoding of incoming text frames.
  """

  use GenServer
  use TypedStruct

  alias Polymarket.WebSocket.MessageHandler

  require Logger
  require Mint.HTTP

  # `Mint.WebSocket.new/4`'s success typing is inferred as error-only (a known
  # Dialyzer limitation: the `with` flow inside its private `do_new/4` hides the
  # `{:ok, conn, websocket}` return), so the matching clause in `handle_responses/2`
  # is flagged as unreachable even though it fires on every successful upgrade.
  @dialyzer {:no_match, handle_responses: 2}

  typedstruct do
    field(:conn, Mint.HTTP.t())
    field(:websocket, Mint.WebSocket.t())
    field(:request_ref, Mint.Types.request_ref())
    field(:caller, GenServer.from())
    field(:status, pos_integer())
    field(:resp_headers, Mint.Types.headers())
    field(:closing?, boolean())
    field(:timer_ref, :timer.tref())
    field(:last_pong, DateTime.t())
  end

  # ---------------------------------------------------------------------------#
  #                                API                                         #
  # ---------------------------------------------------------------------------#

  @doc false
  @spec start_link(term()) :: {:ok, pid()} | {:error, term()}
  def start_link(_opts) do
    with {:ok, socket} <- GenServer.start_link(__MODULE__, []),
         {:ok, :connected} <- GenServer.call(socket, :connect) do
      message = ~S"""
      {
        "assets_ids": [],
        "type": "market",
        "custom_feature_enabled": true
      }
      """

      send_message(socket, message)
      {:ok, socket}
    end
  end

  @doc """
  Sends a string as a message over the websocket.
  """
  @spec send_message(pid(), String.t()) :: :ok
  def send_message(pid, text) do
    GenServer.call(pid, {:send_text, text})
  end

  # ---------------------------------------------------------------------------#
  #                                GenServer                                   #
  # ---------------------------------------------------------------------------#

  @impl GenServer
  def init([]) do
    {:ok, timer} = :timer.send_interval(to_timeout(second: 3), :send_ping)
    {:ok, %__MODULE__{timer_ref: timer}}
  end

  @impl GenServer
  def handle_call({:send_text, text}, _from, state) do
    {:ok, state} = send_frame(state, {:text, text})
    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_call(:connect, from, state) do
    uri = URI.parse("wss://ws-subscriptions-clob.polymarket.com/ws/market")

    http_scheme =
      case uri.scheme do
        "ws" -> :http
        "wss" -> :https
      end

    ws_scheme =
      case uri.scheme do
        "ws" -> :ws
        "wss" -> :wss
      end

    # The endpoint is a fixed URL with no query string.
    path = uri.path

    with {:ok, conn} <- Mint.HTTP.connect(http_scheme, uri.host, uri.port, protocols: [:http1]),
         {:ok, conn, ref} <- Mint.WebSocket.upgrade(ws_scheme, conn, path, []) do
      state = %{state | conn: conn, request_ref: ref, caller: from}
      {:noreply, state}
    else
      {:error, reason} ->
        {:reply, {:error, reason}, state}

      {:error, conn, reason} ->
        {:reply, {:error, reason}, put_in(state.conn, conn)}
    end
  end

  @impl GenServer
  def handle_info(:send_ping, state) do
    {:ok, state} = send_frame(state, {:text, "PING"})
    {:noreply, state}
  end

  def handle_info(message, state) do
    case Mint.WebSocket.stream(state.conn, message) do
      {:ok, conn, responses} ->
        state =
          put_in(state.conn, conn)
          |> handle_responses(responses)

        if state.closing? do
          do_close(state)
        else
          {:noreply, state}
        end

      {:error, conn, reason, _responses} ->
        Logger.debug("Error: #{inspect(binding())}")

        state =
          put_in(state.conn, conn)
          |> reply({:error, reason})

        {:stop, :server_disconnected, state}

      :unknown ->
        {:noreply, state}
    end
  end

  # ---------------------------------------------------------------------------#
  #                                Helpers                                     #
  # ---------------------------------------------------------------------------#

  # ---------------------------------------------------------------------------
  # Handle Response

  @spec handle_responses(t(), [Mint.Types.response()]) :: t()
  defp handle_responses(state, responses)

  defp handle_responses(%{request_ref: ref} = state, [{:status, ref, status} | rest]) do
    Logger.debug("Status: #{inspect(status)}")

    put_in(state.status, status)
    |> handle_responses(rest)
  end

  defp handle_responses(%{request_ref: ref} = state, [{:headers, ref, resp_headers} | rest]) do
    Logger.debug("Headers: #{inspect(resp_headers)}")

    put_in(state.resp_headers, resp_headers)
    |> handle_responses(rest)
  end

  # executes
  defp handle_responses(%{request_ref: ref, status: status, resp_headers: resp_headers} = state, [{:done, ref} | rest])
       when is_integer(status) and is_list(resp_headers) do
    Logger.debug("Done")

    case Mint.WebSocket.new(state.conn, ref, status, resp_headers) do
      {:ok, conn, websocket} ->
        %{state | conn: conn, websocket: websocket, status: nil, resp_headers: nil}
        |> reply({:ok, :connected})
        |> handle_responses(rest)

      {:error, conn, reason} ->
        Logger.error("Error in response #{inspect(binding())}")

        put_in(state.conn, conn)
        |> reply({:error, reason})
    end
  end

  defp handle_responses(%{request_ref: ref, websocket: websocket} = state, [{:data, ref, data} | rest])
       when websocket != nil do
    case Mint.WebSocket.decode(websocket, data) do
      {:ok, websocket, frames} ->
        put_in(state.websocket, websocket)
        |> handle_frames(frames)
        |> handle_responses(rest)

      {:error, websocket, reason} ->
        put_in(state.websocket, websocket)
        |> reply({:error, reason})
    end
  end

  defp handle_responses(state, [_response | rest]) do
    handle_responses(state, rest)
  end

  defp handle_responses(state, []), do: state

  # ---------------------------------------------------------------------------
  # Send Frame

  @spec send_frame(t(), Mint.WebSocket.frame() | Mint.WebSocket.shorthand_frame()) ::
          {:ok, t()} | {:error, t(), term()}
  defp send_frame(state, frame) do
    case Mint.WebSocket.encode(state.websocket, frame) do
      {:ok, websocket, data} ->
        state = put_in(state.websocket, websocket)

        case Mint.WebSocket.stream_request_body(state.conn, state.request_ref, data) do
          {:ok, conn} -> {:ok, put_in(state.conn, conn)}
          {:error, conn, reason} -> {:error, put_in(state.conn, conn), reason}
        end

      {:error, websocket, reason} ->
        {:error, put_in(state.websocket, websocket), reason}
    end
  end

  # ---------------------------------------------------------------------------
  # Receive Frame

  @spec handle_frames(t(), [Mint.WebSocket.frame()]) :: t()
  defp handle_frames(state, frames) do
    Enum.reduce(frames, state, fn
      # reply to pings with pongs
      {:ping, data}, state ->
        Logger.debug("Received ping")
        {:ok, state} = send_frame(state, {:pong, data})
        state

      {:close, _code, reason}, state ->
        Logger.debug("Closing connection: #{inspect(reason)}")
        %{state | closing?: true}

      {:text, "PONG"}, state ->
        Logger.debug("Received pong")
        put_in(state.last_pong, DateTime.utc_now())

      {:text, text}, state ->
        handle_text(text, state)

      frame, state ->
        Logger.debug("Unexpected frame received: #{inspect(frame)}")
        state
    end)
  end

  @spec handle_text(String.t(), t()) :: t()
  defp handle_text(text, state) do
    # try and decode the message to json. the message can be a list of
    # events, so deal with those too.
    case decode_message(text) do
      {:ok, messages} ->
        Logger.debug("Received: #{inspect(messages)}")

        messages
        # Can be a single or a list of messages, so always turn it into a list.
        |> List.wrap()
        |> Enum.reduce(state, fn message, state ->
          MessageHandler.handle_message(message, state)
          |> process_result()
        end)

      {:error, err} ->
        log_message(text)
        Logger.warning("failed to decode message #{text} #{inspect(err)}")
        state
    end
  end

  # ---------------------------------------------------------------------------
  # Closing

  @spec do_close(t()) :: {:stop, :normal, t()}
  defp do_close(state) do
    Logger.debug("Closing websocket #{inspect(state)}")
    # Streaming a close frame may fail if the server has already closed
    # for writing.
    _ = send_frame(state, :close)
    Mint.HTTP.close(state.conn)
    {:stop, :normal, state}
  end

  # ---------------------------------------------------------------------------
  # Reply

  @spec reply(t(), term()) :: t()
  defp reply(state, response) do
    if state.caller, do: GenServer.reply(state.caller, response)
    put_in(state.caller, nil)
  end

  # ---------------------------------------------------------------------------
  # Decoding

  @spec decode_message(String.t()) :: {:ok, term()} | {:error, Jason.DecodeError.t()}
  defp decode_message(messages) when is_list(messages) do
    Enum.map(messages, &decode_message/1)
  end

  defp decode_message(message) do
    message
    |> Jason.decode(keys: :atoms)
  end

  # ---------------------------------------------------------------------------
  # Logging for debugging

  @logfile "test/fixtures/polymarket_websocket_responses.txt"
  @spec log_message(String.t()) :: :ok
  defp log_message(text) do
    File.write!(@logfile, text <> "\n", [:append])
  end

  # ---------------------------------------------------------------------------
  # Process response from handler

  @spec process_result({:reply, {:text, String.t()}, t()} | {:noreply, t()}) :: t()
  defp process_result({:reply, frame, state}) do
    {:ok, state} = send_frame(state, frame)
    state
  end

  defp process_result({:noreply, state}) do
    state
  end
end
