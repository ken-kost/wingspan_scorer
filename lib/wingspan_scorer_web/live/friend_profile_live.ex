defmodule WingspanScorerWeb.FriendProfileLive do
  use WingspanScorerWeb, :live_view

  alias WingspanScorer.{Accounts, Games}

  on_mount {WingspanScorerWeb.LiveUserAuth, :live_user_required}

  @impl true
  def mount(%{"user_id" => user_id}, _session, socket) do
    current_user = socket.assigns.current_user

    with {:ok, friend} <-
           Accounts.get_user(user_id,
             actor: current_user,
             load: [:total_games, :games_won, :highest_score, :lowest_score, :average_score]
           ),
         {:ok, games} <-
           Games.list_user_completed_games(user_id, actor: current_user) do
      {:ok,
       assign(socket,
         friend: friend,
         games: games,
         expanded_game_id: nil
       )}
    else
      {:error, _} ->
        {:ok,
         socket
         |> put_flash(:error, "Could not load profile.")
         |> push_navigate(to: ~p"/friends")}
    end
  end

  @impl true
  def handle_event("toggle_game", %{"game-id" => game_id}, socket) do
    expanded =
      if socket.assigns.expanded_game_id == game_id, do: nil, else: game_id

    {:noreply, assign(socket, expanded_game_id: expanded)}
  end

  defp format_stat(nil), do: "—"
  defp format_stat(value) when is_float(value), do: round(value)
  defp format_stat(value), do: value

  defp format_date_time(nil), do: "—"
  defp format_date_time(%DateTime{} = dt), do: Calendar.strftime(dt, "%b %d, %Y %H:%M")
  defp format_date_time(%Date{} = d), do: Calendar.strftime(d, "%b %d, %Y")

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
      <div class="space-y-8">
        <div class="flex items-center gap-3 mb-2">
          <.link navigate={~p"/friends"} class="btn btn-ghost btn-sm">
            ← Back to Friends
          </.link>
        </div>

        <div class="card bg-base-200 p-6">
          <h1 class="text-2xl font-bold mb-1">{@friend.name || @friend.email}</h1>
          <p class="text-base-content/60 text-sm mb-6">Player profile</p>

          <h2 class="text-xl font-semibold mb-4">Stats</h2>
          <div class="grid grid-cols-2 sm:grid-cols-5 gap-3">
            <div class="bg-base-100 rounded-lg p-4 text-center">
              <div class="text-2xl font-bold text-primary">{format_stat(@friend.total_games)}</div>
              <div class="text-xs text-base-content/60 mt-1">Games Played</div>
            </div>
            <div class="bg-base-100 rounded-lg p-4 text-center">
              <div class="text-2xl font-bold text-success">{format_stat(@friend.games_won)}</div>
              <div class="text-xs text-base-content/60 mt-1">Games Won</div>
            </div>
            <div class="bg-base-100 rounded-lg p-4 text-center">
              <div class="text-2xl font-bold">{format_stat(@friend.highest_score)}</div>
              <div class="text-xs text-base-content/60 mt-1">Highest Score</div>
            </div>
            <div class="bg-base-100 rounded-lg p-4 text-center">
              <div class="text-2xl font-bold">{format_stat(@friend.lowest_score)}</div>
              <div class="text-xs text-base-content/60 mt-1">Lowest Score</div>
            </div>
            <div class="bg-base-100 rounded-lg p-4 text-center col-span-2 sm:col-span-1">
              <div class="text-2xl font-bold">{format_stat(@friend.average_score)}</div>
              <div class="text-xs text-base-content/60 mt-1">Average Score</div>
            </div>
          </div>
        </div>

        <div class="card bg-base-200 p-6">
          <h2 class="text-xl font-semibold mb-4">Game History</h2>
          <%= if @games == [] do %>
            <p class="text-base-content/70">No completed games yet.</p>
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
                        {format_date_time(game.inserted_at)}
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
                        id={"friend-history-#{game.id}"}
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
      </div>
    </Layouts.app>
    """
  end
end
