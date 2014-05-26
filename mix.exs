Code.ensure_loaded?(Hex) and Hex.start

defmodule Workex.Mixfile do
  use Mix.Project

  def project do
    [
      app: :workex,
      version: "0.1.0",
      elixir: "~> 0.13.3",
      deps: deps,
      package: [
        contributors: ["Saša Jurić"],
        licenses: ["MIT"],
        links: [{"Github", "https://github.com/sasa1977/workex"}]
      ],
      description: "Backpressure and flow control in EVM processes."
    ]
  end

  def application do
    []
  end

  defp deps do
    [{:exactor, "0.4.0"}]
  end
end
