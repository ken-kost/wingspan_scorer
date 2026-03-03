defmodule WingspanScorer.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    init_mnesia()

    children = [
      WingspanScorerWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:wingspan_scorer, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: WingspanScorer.PubSub},
      # Start a worker by calling: WingspanScorer.Worker.start_link(arg)
      # {WingspanScorer.Worker, arg},
      # Start to serve requests, typically the last entry
      WingspanScorerWeb.Endpoint,
      {AshAuthentication.Supervisor, [otp_app: :wingspan_scorer]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: WingspanScorer.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp init_mnesia do
    case :mnesia.create_schema([node()]) do
      :ok -> :ok
      {:error, {_, {:already_exists, _}}} -> :ok
    end

    Ash.DataLayer.Mnesia.start(WingspanScorer.Accounts)
    Ash.DataLayer.Mnesia.start(WingspanScorer.Games)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    WingspanScorerWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
