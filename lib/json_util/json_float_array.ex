defmodule Polymarket.JsonUtil.JsonFloatArray do
  @moduledoc """
  Ecto type for Gamma API fields that arrive as a JSON-encoded *string* holding
  an array of numbers, usually themselves quoted, e.g.:

      "outcomePrices": "[\\"0.505\\", \\"0.495\\"]"

  On `cast` the embedded JSON is decoded and each element is coerced to a
  `float`. An already-decoded list is coerced element-wise, an empty string
  becomes `[]`, and `nil` is passed through.
  """

  use Ecto.Type

  @type t :: [float()]

  @impl Ecto.Type
  def type, do: {:array, :float}

  @impl Ecto.Type
  def cast(value) when is_list(value), do: cast_elements(value)
  def cast(""), do: {:ok, []}

  def cast(value) when is_binary(value) do
    case Jason.decode(value) do
      {:ok, list} when is_list(list) -> cast_elements(list)
      _ -> :error
    end
  end

  def cast(nil), do: {:ok, nil}
  def cast(_other), do: :error

  @impl Ecto.Type
  def load(value), do: {:ok, value}

  @impl Ecto.Type
  def dump(value) when is_list(value) or is_nil(value), do: {:ok, value}
  def dump(_other), do: :error

  # Coerces each element (string or number) to a float, failing as a whole if
  # any element is not numeric.
  @spec cast_elements([term()]) :: {:ok, t()} | :error
  defp cast_elements(list) do
    list
    |> Enum.reduce_while([], fn element, acc ->
      case Ecto.Type.cast(:float, element) do
        {:ok, float} -> {:cont, [float | acc]}
        _ -> {:halt, :error}
      end
    end)
    |> case do
      :error -> :error
      floats -> {:ok, Enum.reverse(floats)}
    end
  end
end
