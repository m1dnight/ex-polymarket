defmodule Polymarket.Geoblock do
  @moduledoc """
  Client for Polymarket's geoblock check (https://polymarket.com/api/geoblock).

  Reports whether the caller's IP is blocked from trading, based on the request's
  detected geolocation.
  """

  alias Polymarket.Http
  alias Polymarket.Schemas.Geoblock

  @url "https://polymarket.com"

  @doc """
  Checks whether the caller's IP is geoblocked by Polymarket.

  Returns a `Polymarket.Schemas.Geoblock` describing whether the request is
  `blocked`, along with the detected `ip`, `country`, and `region`.

  ## Examples

      Polymarket.Geoblock.get_geoblock()
      #=> {:ok, %Polymarket.Schemas.Geoblock{blocked: false, ip: "145.79.198.2", country: "IE", region: "L"}}

  """
  @spec get_geoblock() :: {:ok, Geoblock.t()} | {:error, :get_geoblock_failed}
  def get_geoblock do
    with {:ok, raw} <- Http.get("#{@url}/api/geoblock", [], __MODULE__),
         {:ok, geoblock} <- Geoblock.from_attrs(raw) do
      {:ok, geoblock}
    else
      _err -> {:error, :get_geoblock_failed}
    end
  end
end
