Code.ensure_loaded?(Hex) and Hex.start

defmodule Workex.Mixfile do
  use Mix.Project

  @version "0.10.0"

  def project do
    [
      app: :workex,
      version: @version,
      elixir: "~> 1.0",
      elixirc_paths: elixirc_paths(Mix.env),
      deps: deps,
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      source_url: "https://github.com/sasa1977/workex",
      package: [
        maintainers: ["Saša Jurić"],
        licenses: ["MIT"],
        links: %{
          "Github": "https://github.com/sasa1977/workex",
          "Docs": "http://hexdocs.pm/workex"
        }
      ],
      description: "A behaviour for simple flow control and backpressure.",
      docs: [
        extras: ["README.md"],
        main: "Workex",
        source_url: "https://github.com/sasa1977/workex/",
        source_ref: @version
      ]
    ]
  end

  def application do
    [applications: [:logger]]
  end

  defp deps do
    [
      {:exactor, "~> 2.2.0"},
      {:ex_doc, "~> 0.10.0", only: :docs}
    ]
  end

  defp elixirc_paths(:test), do: ["test/support" | elixirc_paths(:common)]
  defp elixirc_paths(:common), do: ["lib"]
  defp elixirc_paths(_), do: elixirc_paths(:common)
end
