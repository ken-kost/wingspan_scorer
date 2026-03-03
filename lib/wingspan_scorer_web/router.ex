defmodule WingspanScorerWeb.Router do
  use WingspanScorerWeb, :router

  use AshAuthentication.Phoenix.Router

  import AshAuthentication.Plug.Helpers

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {WingspanScorerWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :load_from_session
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :load_from_bearer
    plug :set_actor, :user
  end

  scope "/", WingspanScorerWeb do
    pipe_through :browser

    ash_authentication_live_session :authenticated_routes do
      live "/", DashboardLive
      live "/games/:game_id", DashboardLive
      live "/history", HistoryLive
      live "/friends", FriendsLive
      live "/friends/:user_id", FriendProfileLive
      live "/settings", SettingsLive
    end
  end

  scope "/", WingspanScorerWeb do
    pipe_through :browser

    auth_routes AuthController, WingspanScorer.Accounts.User, path: "/auth"
    sign_out_route AuthController

    sign_in_route register_path: "/register",
                  auth_routes_prefix: "/auth",
                  on_mount: [{WingspanScorerWeb.LiveUserAuth, :live_no_user}],
                  overrides: [
                    WingspanScorerWeb.AuthOverrides,
                    Elixir.AshAuthentication.Phoenix.Overrides.DaisyUI
                  ]
  end

  # Other scopes may use custom stacks.
  # scope "/api", WingspanScorerWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:wingspan_scorer, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: WingspanScorerWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  if Application.compile_env(:wingspan_scorer, :dev_routes) do
    import AshAdmin.Router

    scope "/admin" do
      pipe_through :browser

      ash_admin "/"
    end
  end
end
