defmodule BinPacker.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :bin_packer,
      version: @version,
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      # consolidate_protocols: Mix.env() != :dev,
      elixirc_paths: elixirc_paths(Mix.env()),
      description: "Bin packing constraint solver + cost-optimizer.",
      package: package(),
      deps: deps(),
      docs: docs()
    ]
  end

  defp elixirc_paths(:dev), do: ["lib", "examples"]
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp package do
    [maintainers: ["Michael Shapiro"],
     licenses: ["MIT"],
     links: %{"GitHub": "https://github.com/chassisframework/bin_packer"}]
  end

  defp docs do
    [extras: ["README.md"],
     source_url: "https://github.com/chassisframework/bin_packer",
     source_ref: @version,
     assets: "assets",
     main: "readme"]
  end
end
