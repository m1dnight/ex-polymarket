defmodule Polymarket.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/m1dnight/ex_polymarket"

  def project do
    [
      app: :ex_polymarket,
      version: @version,
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      description: description(),
      package: package(),
      docs: docs(),
      name: "Polymarket",
      source_url: @source_url
    ]
  end

  defp description do
    "An Elixir client for the Polymarket API."
  end

  defp package do
    [
      name: "ex_polymarket",
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib mix.exs README.md LICENSE)
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      extras: ["README.md"]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:mint_web_socket, "~> 1.0"},
      {:mint, "~> 1.9"},
      {:typedstruct, "~> 0.5.4"},
      {:jason, "~> 1.4"},
      {:typed_ecto_schema, "~> 0.4.3"},
      {:quokka, "~> 2.13", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      precommit: [
        "format",
        "credo --strict",
        "compile --warnings-as-errors",
        "deps.unlock --unused",
        "dialyzer"
      ]
    ]
  end
end
