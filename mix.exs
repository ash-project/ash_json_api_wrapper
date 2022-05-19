defmodule AshJsonApiWrapper.MixProject do
  use Mix.Project

  def project do
    [
      app: :ash_json_api_wrapper,
      version: "0.1.0",
      elixir: "~> 1.12",
      aliases: aliases(),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp aliases do
    [
      "ash.formatter": "ash.formatter --extensions AshJsonApiWrapper.DataLayer"
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ash, "~> 1.52.0-rc.8"},
      {:finch, "~> 0.9.0"},
      {:exjsonpath, "~> 0.1"},
      # Dev/Test dependencies
      {:ex_doc, "~> 0.22", only: :dev, runtime: false},
      {:ex_check, "~> 0.12.0", only: :dev},
      {:credo, ">= 0.0.0", only: :dev, runtime: false},
      {:dialyxir, ">= 0.0.0", only: :dev, runtime: false},
      {:sobelow, ">= 0.0.0", only: :dev, runtime: false},
      {:git_ops, "~> 2.4.4", only: :dev},
      {:excoveralls, "~> 0.13.0", only: [:dev, :test]},
      {:mix_test_watch, "~> 1.0", only: :dev, runtime: false},
      {:parse_trans, "3.3.0", only: [:dev, :test], override: true}
    ]
  end
end
