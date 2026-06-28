defmodule Polymarket.Gamma do
  @moduledoc """
  Client for the Polymarket Gamma REST API (https://gamma-api.polymarket.com).
  """

  alias Polymarket.Http
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

  # ---------------------------------------------------------------------------#
  #                                Helpers                                     #
  # ---------------------------------------------------------------------------#

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
