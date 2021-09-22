import Config

config :logger, :console,
  format: "$metadata[$level] $message\n",
  metadata: [:error]

# Configures all loggers, not just the console,
# as the console isn't used in tests when capture_log is active.
Logger.configure(level: :info)
