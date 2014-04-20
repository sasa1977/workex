defmodule Workex.Mixfile do
  use Mix.Project

  def project do
    [ app: :workex,
      version: "0.0.1",
      elixir: ">= 0.13.0",
      deps: deps ]
  end

  def application do
    []
  end

  defp deps do
    [{:exactor, github: "sasa1977/exactor"}]
  end
end
