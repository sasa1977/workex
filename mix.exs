Code.ensure_loaded?(Hex) and Hex.start

defmodule Workex.Mixfile do
  use Mix.Project

  @version "0.9.0"

  def project do
    [
      app: :workex,
      version: @version,
      elixir: "~> 1.0",
      deps: deps,
      source_url: "https://github.com/sasa1977/workex",
      package: [
        contributors: ["Saša Jurić"],
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
    [applications: [:exactor, :logger]]
  end

  defp deps do
    [
      {:exactor, "~> 2.2.0"},
      {:ex_doc, "~> 0.10.0", only: :docs}
    ]
  end
end
