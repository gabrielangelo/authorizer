import Config

config :cli, Cli.Ports.Stdin, implementation: StdinMock


config :logger, level: :warn
