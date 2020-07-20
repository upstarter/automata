defmodule Automata.MixProject do
  use Mix.Project

  def project do
    [
      app: :automata,
      version: "0.1.0",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      elixirc_paths: elixirc_paths(Mix.env()),
      elixirc_options: [warnings_as_errors: true],
      ignore_module_conflict: true,
      dialyzer: [
        ignore_warnings: ".dialyzer-ignore",
        # as filters tend to become obsolete
        list_unused_filters: true,
        # only Direct OTP runtime application dependencies - not the entire tree
        plt_add_deps: :apps_direct
      ],
      preferred_cli_env: [ExUnit: :test],
      docs: [
        output: "docs",
        extras: [
          "README.md": [title: "ReadMe"],
          "CONTRIBUTING.md": [title: "Contributing"]
        ]
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/fixtures", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      registered: [
        # Automata.OnExitHandler,
        Automata.Supervisor
      ],
      extra_applications: [:logger],
      mod: mod(),
      env: [
        # Calculated on demand
        # max_automata: System.schedulers_online * 2,
        # seed: rand(),
        # formatters: [Automata.CLIFormatter],

        autorun: true,
        max_failures: :infinity,
        refute_receive_timeout: 100,
        timeout: 60000,
        trace: false,
        after_automata: []
      ]
    ]
  end

  defp mod() do
    {Automata, []}
  end

  defp aliases() do
    [
      # test: "test --no-start"
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:dialyxir, "~> 1.0.0-rc.7", only: [:dev], runtime: false},
      {:credo, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.21", only: :dev, runtime: false},
      {:ecto, "~> 3.0"},
      {:ksuid, "~> 0.1.2"},
      {:temp, "~> 0.4"},
      {:matrex, "~> 0.6"}
    ]
  end
end
