defmodule Polymarket.JsonUtil.JsonStringArray do
  @moduledoc """
  Ecto type for Gamma API fields that arrive as a JSON-encoded *string*
  instead of a real JSON array, e.g.:

      "outcomes": "[\\"Lafayette Leopards\\", \\"Colgate Raiders\\"]"

  On `cast` the embedded JSON is decoded into a `[String.t()]` list. An
  already-decoded list (e.g. hand-written test data) is passed through
  unchanged.
  """

  use Ecto.Type

  @type t :: [String.t()]
  @impl Ecto.Type
  def type, do: {:array, :string}

  @impl Ecto.Type
  def cast(value) when is_list(value) do
    {:ok, value}
  end

  def cast("") do
    {:ok, []}
  end

  def cast(value) when is_binary(value) do
    case Jason.decode(value) do
      {:ok, list} when is_list(list) -> {:ok, list}
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
end
