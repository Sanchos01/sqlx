defmodule Sqlx.Mixfile do
  use Mix.Project

  def project do
    [app: :sqlx,
     version: "0.0.1",
     elixir: "~> 1.0",
     deps: deps]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [applications: 	[
    					:logger,
    					:emysql,
    					:silverb,
              :logex,
              :exutils,
			  :timex,
    				],
     mod: {Sqlx, []}]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type `mix help deps` for more examples and options
  defp deps do
   	[
  		{:emysql, github: "timCF/Emysql"},
  		{:silverb, github: "timCF/silverb"},
      {:logex, github: "timCF/logex"},
      {:exutils, github: "timCF/exutils"},
	  {:timex, github: "bitwalker/timex", tag: "2.2.1"},
   	]
  end
end
