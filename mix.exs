defmodule AshJsonApiWrapper.MixProject do
  use Mix.Project

  @description """
  A data layer for building resources backed by external JSON APIs
  """

  @version "0.1.0"

  def project do
    [
      app: :ash_json_api_wrapper,
      version: @version,
      consolidate_protocols: Mix.env() != :test,
      elixir: "~> 1.12",
      aliases: aliases(),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      elixirc_paths: elixirc_paths(Mix.env()),
      dialyzer: [plt_add_apps: [:ash]],
      docs: docs(),
      description: @description,
      source_url: "https://github.com/ash-project/ash_json_api",
      homepage_url: "https://github.com/ash-project/ash_json_api"
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp extras() do
    "documentation/**/*.md"
    |> Path.wildcard()
    |> Enum.map(fn path ->
      title =
        path
        |> Path.basename(".md")
        |> String.split(~r/[-_]/)
        |> Enum.map(&String.capitalize/1)
        |> Enum.join(" ")
        |> case do
          "F A Q" ->
            "FAQ"

          other ->
            other
        end

      {String.to_atom(path),
       [
         title: title
       ]}
    end)
  end

  defp groups_for_extras() do
    "documentation/*"
    |> Path.wildcard()
    |> Enum.map(fn folder ->
      name =
        folder
        |> Path.basename()
        |> String.split(~r/[-_]/)
        |> Enum.map(&String.capitalize/1)
        |> Enum.join(" ")

      {name, folder |> Path.join("**") |> Path.wildcard()}
    end)
  end

  defp docs do
    [
      main: "AshJsonApiWrapper",
      source_ref: "v#{@version}",
      logo: "logos/small-logo.png",
      extra_section: "GUIDES",
      spark: [
        extensions: [
          %{
            module: AshJsonApiWrapper.DataLayer,
            name: "AshJsonApiWrapper",
            target: "Ash.Resource",
            type: "DataLayer"
          }
        ]
      ],
      extras: extras(),
      groups_for_extras: groups_for_extras(),
      groups_for_modules: [
        AshJsonApiWrapper: [
          AshJsonApiWrapper,
          AshJsonApiWrapper.DataLayer
        ],
        Introspection: [
          AshJsonApiWrapper.DataLayer.Info
        ],
        Internals: ~r/.*/
      ]
    ]
  end

  defp aliases do
    [
      sobelow: "sobelow --skip",
      docs: ["docs", "spark.replace_doc_links"],
      "spark.formatter": "spark.formatter --extensions AshJsonApiWrapper.DataLayer"
    ]
  end

  defp package do
    [
      name: :ash_json_api_wrapper,
      licenses: ["MIT"],
      files: ~w(lib .formatter.exs mix.exs README* LICENSE*
      CHANGELOG* documentation),
      links: %{
        GitHub: "https://github.com/ash-project/ash_json_api_wrapper"
      }
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ash, ash_version("~> 2.15")},
      {:tesla, "~> 1.7"},
      {:exjsonpath, "~> 0.1"},
      # Dev/Test dependencies
      {:ex_doc, "~> 0.22", only: :dev, runtime: false},
      {:ex_check, "~> 0.16.0", only: :dev},
      {:credo, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:dialyxir, ">= 0.0.0", only: :dev, runtime: false},
      {:sobelow, "~> 0.13", only: [:dev, :test], runtime: false},
      {:git_ops, "~> 2.5", only: :dev},
      {:mix_test_watch, "~> 1.0", only: :dev, runtime: false},
      {:parse_trans, "3.4.2", only: [:dev, :test], override: true},
      {:mox, "~> 1.0", only: :test},
      {:mix_audit, ">= 0.0.0", only: [:dev, :test], runtime: false}
    ]
  end

  defp ash_version(default_version) do
    case System.get_env("ASH_VERSION") do
      nil -> default_version
      "local" -> [path: "../ash"]
      "main" -> [git: "https://github.com/ash-project/ash.git"]
      version -> "~> #{version}"
    end
  end

  defp elixirc_paths(:test) do
    elixirc_paths(:dev) ++ ["test/support"]
  end

  defp elixirc_paths(_) do
    ["lib"]
  end
end
