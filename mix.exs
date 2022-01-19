defmodule Protobuf.Mixfile do
  use Mix.Project

  def project do
    [
      app: :protobuf,
      version: version(),
      elixir: "~> 1.12",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      escript: escript(),
      description: description(),
      package: package()
    ]
  end

  def application do
    [
      mod: {Protobuf.Application, []},
      extra_applications: [:logger]
    ]
  end

  defp version do
    case File.read("VERSION") do
      {:ok, v} -> String.trim(v)
      {:error, _} -> "0.0.0-development"
    end
  end

  defp elixirc_paths(:test), do: ["lib", "test/support", "test/protobuf/protoc/proto_gen"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:dialyxir, "~> 0.5", only: [:dev, :test], runtime: false},
      {:credo, "~> 0.8", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.14", only: :dev, runtime: false},
      {:eqc_ex, "~> 1.4", only: [:dev, :test]},
      {:ex_doc, "~> 0.19", only: [:dev, :test], runtime: false}
    ]
  end

  defp escript do
    [main_module: Protobuf.Protoc.CLI, name: "protoc-gen-elixir"]
  end

  defp description do
    "A pure Elixir implementation of Google Protobuf."
  end

  defp package do
    [
      organization: "coingaming",
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/tony612/protobuf-elixir"},
      files:
        ~w(mix.exs VERSION README.md lib/google lib/protobuf lib/*.ex src LICENSE priv/templates .formatter.exs)
    ]
  end
end
