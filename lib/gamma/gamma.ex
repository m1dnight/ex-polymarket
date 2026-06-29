defmodule Polymarket.Gamma do
  @moduledoc """
  Client for the Polymarket Gamma REST API (https://gamma-api.polymarket.com).
  """

  alias Polymarket.Http
  alias Polymarket.Schemas.Event
  alias Polymarket.Schemas.Market
  alias Polymarket.Schemas.Tag

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
    with {:ok, raw} <- Http.get("#{@url}/markets/#{market_id}", opts, __MODULE__),
         {:ok, market} <- Market.from_attrs(raw) do
      {:ok, market}
    else
      _err -> {:error, :get_market_failed}
    end
  end

  @doc """
  Retrieves a single market by its unique slug.

  Returns detailed information about a market.

  ## Options

  `opts` are sent verbatim as query parameters. The Gamma API supports:

    * `:include_tag` - when `true`, includes the market's `tags` in the response.

  ## Examples

      Polymarket.Gamma.get_market_by_slug("sol-updown-5m-1782566100", include_tag: true)

  """
  @spec get_market_by_slug(String.t(), options()) ::
          {:ok, Market.t()} | {:error, :get_market_failed}
  def get_market_by_slug(slug, opts \\ []) do
    with {:ok, raw} <- Http.get("#{@url}/markets/slug/#{slug}", opts, __MODULE__),
         {:ok, market} <- Market.from_attrs(raw) do
      {:ok, market}
    else
      _err -> {:error, :get_market_failed}
    end
  end

  @doc """
  Retrieves the tags attached to a market by the market's unique ID.

  Returns the list of `Polymarket.Schemas.Tag` structs for the market.

  ## Examples

      Polymarket.Gamma.get_market_tags(2_691_932)

  """
  @spec get_market_tags(non_neg_integer() | String.t()) ::
          {:ok, [Tag.t()]} | {:error, :get_market_tags_failed}
  def get_market_tags(market_id) do
    with {:ok, raw} when is_list(raw) <- Http.get("#{@url}/markets/#{market_id}/tags", [], __MODULE__),
         {:ok, tags} <- parse_tags(raw) do
      {:ok, tags}
    else
      _err -> {:error, :get_market_tags_failed}
    end
  end

  @doc """
  Fetches a single page of events using the keyset (cursor) pagination endpoint
  `GET /events/keyset`.

  Returns the parsed events plus the `next_cursor` to pass as `:after_cursor` on
  the following call. `next_cursor` is `nil` on the last page. To page through
  *all* events, prefer `stream_events/1`.

  ## Options

  `opts` are sent verbatim as query parameters. The keyset endpoint supports many
  filters; the most useful are:

    * `:limit` - max results per page (1..500, default 20)
    * `:after_cursor` - the `next_cursor` from a previous response
    * `:order` / `:ascending` - sort field and direction
    * `:closed` / `:active` / `:archived` / `:featured` - status filters
    * `:tag_id` / `:tag_slug` - tag filters

  The `:offset` parameter is rejected by the endpoint; use `:after_cursor`.

  ## Examples

      Polymarket.Gamma.list_events(limit: 100, closed: false)

  """
  @spec list_events(keyword()) ::
          {:ok, %{events: [Event.t()], next_cursor: String.t() | nil}}
          | {:error, :list_events_failed}
  def list_events(opts \\ []) do
    with {:ok, %{events: raw} = body} when is_list(raw) <-
           Http.get("#{@url}/events/keyset", opts, __MODULE__),
         {:ok, events} <- parse_events(raw) do
      {:ok, %{events: events, next_cursor: Map.get(body, :next_cursor)}}
    else
      _err -> {:error, :list_events_failed}
    end
  end

  @doc """
  Returns a lazy `Stream` of every event matching `opts`, transparently following
  the keyset cursor across pages.

  Each element is a `Polymarket.Schemas.Event`. The stream fetches one page at a
  time as it is consumed, so it is safe to use over the full (large) event set,
  e.g. with `Stream.take/2`. Materialise the whole result with `Enum.to_list/1`.

  `opts` are forwarded to `list_events/1` (an `:after_cursor` in `opts` is used as
  the starting page). A larger `:limit` reduces the number of round-trips.

  Raises if a page fails to fetch, so that a partial result is never silently
  mistaken for the complete set.

  ## Examples

      # All open events.
      Polymarket.Gamma.stream_events(closed: false) |> Enum.to_list()

      # Just the first 50, without fetching everything.
      Polymarket.Gamma.stream_events(limit: 100) |> Enum.take(50)

  """
  @spec stream_events(keyword()) :: Enumerable.t()
  def stream_events(opts \\ []) do
    base = Keyword.delete(opts, :after_cursor)

    Stream.resource(
      fn -> {:fetch, Keyword.get(opts, :after_cursor)} end,
      fn
        :halt ->
          {:halt, nil}

        {:fetch, cursor} ->
          page_opts = if cursor, do: Keyword.put(base, :after_cursor, cursor), else: base

          case list_events(page_opts) do
            {:ok, %{events: events, next_cursor: nil}} -> {events, :halt}
            {:ok, %{events: events, next_cursor: next}} -> {events, {:fetch, next}}
            {:error, reason} -> raise "Polymarket.Gamma.stream_events failed: #{inspect(reason)}"
          end
      end,
      fn _acc -> :ok end
    )
  end

  # ---------------------------------------------------------------------------#
  #                                Helpers                                     #
  # ---------------------------------------------------------------------------#

  # Parse a list of raw event attrs, failing fast if any element is invalid.
  @spec parse_events([map()]) :: {:ok, [Event.t()]} | {:error, Ecto.Changeset.t()}
  defp parse_events(raw) do
    raw
    |> Enum.reduce_while({:ok, []}, fn attrs, {:ok, acc} ->
      case Event.from_attrs(attrs) do
        {:ok, event} -> {:cont, {:ok, [event | acc]}}
        {:error, _changeset} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, events} -> {:ok, Enum.reverse(events)}
      error -> error
    end
  end

  # Parse a list of raw tag attrs, failing fast if any element is invalid.
  @spec parse_tags([map()]) :: {:ok, [Tag.t()]} | {:error, Ecto.Changeset.t()}
  defp parse_tags(raw) do
    raw
    |> Enum.reduce_while({:ok, []}, fn attrs, {:ok, acc} ->
      case Tag.from_attrs(attrs) do
        {:ok, tag} -> {:cont, {:ok, [tag | acc]}}
        {:error, _changeset} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, tags} -> {:ok, Enum.reverse(tags)}
      error -> error
    end
  end
end
