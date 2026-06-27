defmodule Polymarket.JsonUtil do
  @moduledoc """
  Helpers for massaging raw JSON (as decoded from an external API) into the shape
  expected by our Ecto schemas.
  """

  @doc """
  Recursively rewrites a map's `camelCase` keys (atom or string) into
  `snake_case` string keys, descending into nested maps and lists.

  Bridges the Gamma API's `camelCase` payloads to our `snake_case` schema fields.

      iex> Polymarket.JsonUtil.snake_case_keys(%{conditionId: "0x1", feeSchedule: %{rebateRate: 0.2}})
      %{"condition_id" => "0x1", "fee_schedule" => %{"rebate_rate" => 0.2}}
  """
  @spec snake_case_keys(map()) :: map()
  def snake_case_keys(attrs) when is_map(attrs) do
    Recase.Enumerable.stringify_keys(attrs, &Recase.to_snake/1)
  end
end
