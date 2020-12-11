import Config

# Print only warnings and errors during test
config :logger, level: :warn

# Configures application server port
config :todo,
  http: [port: 4001]
