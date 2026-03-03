defmodule WingspanScorerWeb.HistoryLive do
  use WingspanScorerWeb, :live_view

  alias WingspanScorer.Games

  on_mount {WingspanScorerWeb.LiveUserAuth, :live_user_required}

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    games = load_completed_games(user)
    {:ok, assign(socket, games: games, expanded_game_id: nil)}
  end

  @impl true
  def handle_event("toggle_game", %{"game-id" => game_id}, socket) do
    expanded =
      if socket.assigns.expanded_game_id == game_id, do: nil, else: game_id

    {:noreply, assign(socket, expanded_game_id: expanded)}
  end

  defp load_completed_games(user) do
    case Games.list_my_games(actor: user, load: [game_players: [:user]]) do
      {:ok, games} -> Enum.filter(games, & &1.completed)
      {:error, _} -> []
    end
  end

  defp format_date_time(nil, nil), do: "Unknown date"
  defp format_date_time(nil, %DateTime{} = dt), do: Calendar.strftime(dt, "%b %d, %Y %H:%M")
  defp format_date_time(%Date{} = d, nil), do: Calendar.strftime(d, "%b %d, %Y")

  defp format_date_time(%Date{} = d, %DateTime{} = dt) do
    Calendar.strftime(d, "%b %d, %Y") <> " " <> Calendar.strftime(dt, "%H:%M")
  end

  defp player_name(player) do
    cond do
      player.user_id != nil and player.user != nil and player.user.name not in [nil, ""] ->
        player.user.name

      player.user_id != nil and player.user != nil ->
        player.user.email

      player.guest_name not in [nil, ""] ->
        player.guest_name

      true ->
        "Player"
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="card bg-base-200 p-6">
        <h1 class="text-2xl font-bold mb-4">Game History</h1>

        <%= if @games == [] do %>
          <p class="text-base-content/70">No completed games yet. Finish a game to see it here!</p>
        <% else %>
          <div class="space-y-2">
            <%= for game <- @games do %>
              <% expanded = game.id == @expanded_game_id %>
              <div class="bg-base-100 rounded-lg overflow-hidden">
                <button
                  class="w-full flex items-center justify-between p-4 text-left hover:bg-base-200 transition-colors"
                  phx-click="toggle_game"
                  phx-value-game-id={game.id}
                >
                  <div class="flex flex-wrap items-center gap-2">
                    <span class="font-medium">
                      {format_date_time(game.played_at, game.inserted_at)}
                    </span>
                    <%= for expansion <- game.expansions, expansion != :base do %>
                      <span class="badge badge-sm badge-outline capitalize">{expansion}</span>
                    <% end %>
                  </div>
                  <div class="flex items-center gap-3 shrink-0 ml-4">
                    <span class="text-sm text-base-content/70 hidden sm:block">
                      {Enum.map_join(game.game_players, ", ", &player_name/1)}
                    </span>
                    <.icon
                      name={if expanded, do: "hero-chevron-up", else: "hero-chevron-down"}
                      class="size-4"
                    />
                  </div>
                </button>

                <%= if expanded do %>
                  <div class="p-4 border-t border-base-300">
                    <p class="text-sm text-base-content/70 mb-3 sm:hidden">
                      {Enum.map_join(game.game_players, ", ", &player_name/1)}
                    </p>
                    <.live_component
                      module={WingspanScorerWeb.ScoringFormComponent}
                      id={"history-#{game.id}"}
                      game={game}
                      players={game.game_players}
                      current_user={@current_user}
                      read_only={true}
                    />
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
