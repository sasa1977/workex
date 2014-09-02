Code.ensure_loaded?(Hex) and Hex.start

defmodule Workex.Mixfile do
  use Mix.Project

  def project do
    [
      app: :workex,
      version: "0.3.0",
      elixir: "~> 1.0.0-rc1",
      deps: deps,
      package: [
        contributors: ["Saša Jurić"],
        licenses: ["MIT"],
        links: %{"Github": "https://github.com/sasa1977/workex"}
      ],
      description: "Backpressure and flow control in EVM processes."
    ]
  end

  def application do
    [applications: [:exactor, :logger]]
  end

  defp deps do
    [{:exactor, "0.7.0"}]
  end
end
