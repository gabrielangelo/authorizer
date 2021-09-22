import Config

config :cli, Cli.Ports.Stdin, implementation: Cli.Adapters.Stdin

import_config "#{Mix.env()}.exs"
