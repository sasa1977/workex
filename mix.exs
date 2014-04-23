defmodule Workex.Mixfile do
  use Mix.Project

  def project do
    [
      app: :workex,
      version: "0.0.1",
      elixir: ">= 0.13.0",
      deps: deps,
      package: [
        contributors: ["Saša Jurić"],
        licenses: ["MIT"],
        links: [{"Github", "https://github.com/sasa1977/workex"}]
      ],
      description: """
        Backpressure and flow control in EVM processes.
      """
    ]
  end

  def application do
    []
  end

  defp deps do
    [{:exactor, "0.2.1", github: "sasa1977/exactor"}]
  end
end
