defmodule Cli.MixProject do
  use Mix.Project

  def project do
    [
      app: :cli,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      escript: [
        main_module: Cli.Scripts.Authorizer
      ],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      test_coverage: [tool: ExCoveralls]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Cli.Application, []},
      escript: [
        main_module: Cli.Scripts.Authorizer,
        comment: "A sample escript",
        name: :cli_authorizer
      ]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"},
      # {:sibling_app_in_umbrella, in_umbrella: true}
      {:core, in_umbrella: true},
      {:dialyxir, "~> 1.0.0", runtime: false, allow_pre: false, only: [:dev, :test]},
      {:credo, "~> 1.5.5", only: [:dev, :test], runtime: false},
      {:ecto_sql, "~> 3.0"},
      {:jason, "~> 1.2"},
      {:mox, "~> 1.0", only: :test},
      {:excoveralls, "~> 0.10", only: :test},
    ]
  end
end
