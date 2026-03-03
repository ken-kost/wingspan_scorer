import Config
config :wingspan_scorer, token_signing_secret: "FIXJGPvZtlA9xvTz14sn5zToBzkyK46I"
config :bcrypt_elixir, log_rounds: 1
config :ash, policies: [show_policy_breakdowns?: true], disable_async?: true

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :wingspan_scorer, WingspanScorerWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "5ksxdRXuiXL3eqK9uf8HNmy+lZ5by3g+VGVlSFlej6waArmJjWsi+RVJ1YQ7ezk0",
  server: false

# In test we don't send emails
config :wingspan_scorer, WingspanScorer.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true
