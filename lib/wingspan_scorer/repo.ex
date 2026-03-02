defmodule WingspanScorer.Repo do
  use Ecto.Repo,
    otp_app: :wingspan_scorer,
    adapter: Ecto.Adapters.Postgres
end
