defmodule FEnum.MixProject do
  use Mix.Project

  @version "0.2.0"
  @source_url "https://github.com/PJUllrich/f_enum"

  def project do
    [
      app: :f_enum,
      version: @version,
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      docs: docs(),
      name: "FEnum",
      description:
        "A drop-in replacement for Enum backed by Rust NIFs. Up to 10x faster sorting, 6x faster uniq, and near-zero memory allocation for integer lists.",
      source_url: @source_url,
      homepage_url: @source_url
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:rustler, "~> 0.37"},
      {:ex_doc, "~> 0.35", only: :dev, runtime: false},
      {:benchee, "~> 1.3", only: :dev},
      {:benchee_html, "~> 1.0", only: :dev}
    ]
  end

  defp package do
    [
      name: "f_enum",
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url
      },
      files: ~w(
        lib
        native/f_enum_nif/src
        native/f_enum_nif/Cargo.toml
        .formatter.exs
        mix.exs
        README.md
        LICENSE
      )
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"],
      source_ref: "v#{@version}",
      source_url: @source_url
    ]
  end
end
