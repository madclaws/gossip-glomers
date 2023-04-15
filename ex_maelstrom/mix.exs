defmodule ExMaelstrom.MixProject do
  use Mix.Project

  def project do
    [
      app: :ex_maelstrom,
      version: "0.1.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: [
        ex_maelstrom: [
          steps: [:assemble, &Bakeware.assemble/1],
          strip_beams: Mix.env() == :prod,
          overwrite: true
        ]
      ],
      aliases: aliases()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {ExMaelstrom.Application, []},
      extra_applications: [:logger]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:jason, "~> 1.2"},
      {:mox, "~> 1.0", only: :test},
      {:bakeware, path: "/home/madclaws/labs/bakeware", runtime: false}
    ]
  end

  defp aliases do
    [
      bake: ["deps.get", "compile", "release"]
    ]
  end
end
