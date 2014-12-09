Code.ensure_loaded?(Hex) and Hex.start

defmodule Workex.Mixfile do
  use Mix.Project

  def project do
    [
      app: :workex,
      version: "0.7.0",
      elixir: "~> 1.0.0",
      deps: deps,
      package: [
        contributors: ["Saša Jurić"],
        licenses: ["MIT"],
        links: %{
          "Github": "https://github.com/sasa1977/workex",
          "Docs": "http://hexdocs.pm/workex"
        }
      ],
      description: "A behaviour for simple flow control and backpressure."
    ]
  end

  def application do
    [applications: [:exactor, :logger]]
  end

  defp deps do
    [
      {:exactor, "~> 2.0.0"},
      {:ex_doc, "~> 0.7.0", only: :docs}
    ]
  end
end
