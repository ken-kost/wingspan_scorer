defmodule WingspanScorerWeb.DashboardLive do
  use WingspanScorerWeb, :live_view

  alias WingspanScorer.{Accounts, Games}

  on_mount {WingspanScorerWeb.LiveUserAuth, :live_user_required}

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    games = load_my_games(user)
    user_stats = load_user_stats(user)

    {:ok,
     assign(socket,
       mode: :home,
       games: games,
       user_stats: user_stats,
       game: nil,
       players: [],
       setup_expansions: [:base],
       setup_guest_names: [],
       setup_guest_input: "",
       setup_guest_error: nil,
       setup_selected_friend_ids: [],
       setup_friendships: [],
       show_friend_form: false
     )}
  end

  @impl true
  def handle_params(%{"game_id" => game_id}, _url, socket) do
    user = socket.assigns.current_user

    case Games.get_game(game_id, actor: user, load: [game_players: [:user]]) do
      {:ok, game} ->
        mode = if game.completed, do: :results, else: :scoring
        {:noreply, assign(socket, mode: mode, game: game, players: game.game_players)}

      {:error, _} ->
        {:noreply,
         socket |> put_flash(:error, "Could not load game.") |> push_navigate(to: ~p"/")}
    end
  end

  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("new_game", _params, socket) do
    user = socket.assigns.current_user
    friendships = load_friendships(user)

    {:noreply,
     assign(socket,
       mode: :setup,
       setup_expansions: [:base],
       setup_guest_names: [],
       setup_guest_input: "",
       setup_guest_error: nil,
       setup_selected_friend_ids: [],
       setup_friendships: friendships,
       show_friend_form: false
     )}
  end

  @impl true
  def handle_event("resume_game", %{"game-id" => game_id}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/games/#{game_id}")}
  end

  @impl true
  def handle_event("toggle_expansion", %{"expansion" => expansion}, socket) do
    key = String.to_existing_atom(expansion)
    current = socket.assigns.setup_expansions

    new_expansions =
      if key in current, do: Enum.reject(current, &(&1 == key)), else: current ++ [key]

    {:noreply, assign(socket, setup_expansions: new_expansions)}
  end

  @impl true
  def handle_event("cancel_setup", _params, socket) do
    {:noreply, assign(socket, mode: :home)}
  end

  @impl true
  def handle_event("back_to_home", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/")}
  end

  @impl true
  def handle_event("add_guest", %{"guest_name" => name}, socket) when name != "" do
    names = socket.assigns.setup_guest_names ++ [String.trim(name)]

    {:noreply,
     assign(socket, setup_guest_names: names, setup_guest_input: "", setup_guest_error: nil)}
  end

  def handle_event("add_guest", _params, socket) do
    {:noreply, assign(socket, setup_guest_error: "Guest name cannot be empty.")}
  end

  @impl true
  def handle_event("remove_guest", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    names = List.delete_at(socket.assigns.setup_guest_names, index)
    {:noreply, assign(socket, setup_guest_names: names)}
  end

  @impl true
  def handle_event("toggle_friend_form", _params, socket) do
    {:noreply, assign(socket, show_friend_form: !socket.assigns.show_friend_form)}
  end

  @impl true
  def handle_event("add_single_friend", %{"friend-id" => friend_id}, socket) do
    current = socket.assigns.setup_selected_friend_ids

    new_ids =
      if friend_id in current, do: current, else: current ++ [friend_id]

    {:noreply, assign(socket, setup_selected_friend_ids: new_ids)}
  end

  @impl true
  def handle_event("remove_friend", %{"friend-id" => friend_id}, socket) do
    ids = Enum.reject(socket.assigns.setup_selected_friend_ids, &(&1 == friend_id))
    {:noreply, assign(socket, setup_selected_friend_ids: ids)}
  end

  @impl true
  def handle_event("start_game", _params, socket) do
    user = socket.assigns.current_user

    expansions = socket.assigns.setup_expansions
    friend_ids = socket.assigns.setup_selected_friend_ids
    guest_names = socket.assigns.setup_guest_names

    with {:ok, game} <-
           Games.create_game(
             %{expansions: expansions, played_at: Date.utc_today()},
             actor: user
           ),
         :ok <- add_players(game, user, friend_ids, guest_names) do
      {:noreply, push_navigate(socket, to: ~p"/games/#{game.id}")}
    else
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not start game. Please try again.")}
    end
  end

  defp add_players(game, actor, friend_ids, guest_names) do
    with {:ok, _} <-
           Games.create_game_player(%{game_id: game.id, user_id: actor.id}, actor: actor),
         :ok <- add_friend_players(game, actor, friend_ids) do
      add_guest_players(game, actor, guest_names)
    end
  end

  defp add_friend_players(_game, _actor, []), do: :ok

  defp add_friend_players(game, actor, [friend_id | rest]) do
    case Games.create_game_player(%{game_id: game.id, user_id: friend_id}, actor: actor) do
      {:ok, _} -> add_friend_players(game, actor, rest)
      {:error, e} -> {:error, e}
    end
  end

  defp add_guest_players(_game, _actor, []), do: :ok

  defp add_guest_players(game, actor, [guest_name | rest]) do
    case Games.create_game_player(%{game_id: game.id, guest_name: guest_name}, actor: actor) do
      {:ok, _} -> add_guest_players(game, actor, rest)
      {:error, e} -> {:error, e}
    end
  end

  @impl true
  def handle_info({:game_saved}, socket) do
    user = socket.assigns.current_user
    games = load_my_games(user)
    user_stats = load_user_stats(user)
    {:noreply, assign(socket, mode: :results, games: games, user_stats: user_stats)}
  end

  defp load_my_games(user) do
    case Games.list_my_games(actor: user) do
      {:ok, games} -> Enum.reject(games, & &1.completed)
      {:error, _} -> []
    end
  end

  defp load_user_stats(user) do
    case Ash.load(user, [:total_games, :games_won, :highest_score, :lowest_score, :average_score],
           actor: user
         ) do
      {:ok, loaded} -> loaded
      {:error, _} -> user
    end
  end

  defp load_friendships(user) do
    case Accounts.list_my_friendships(actor: user, load: [:friend]) do
      {:ok, friendships} -> friendships
      {:error, _} -> []
    end
  end

  defp expansion_options do
    [
      {:oceania, "Oceania"},
      {:americas, "Americas"}
    ]
  end

  defp find_friendship(friendships, friend_id) do
    Enum.find(friendships, fn f -> f.friend_id == friend_id end)
  end

  defp friend_display_name(friendship) do
    friendship.friend.name || friendship.friend.email
  end

  defp format_date_time(nil, nil), do: "—"
  defp format_date_time(nil, %DateTime{} = dt), do: Calendar.strftime(dt, "%b %d, %Y %H:%M")
  defp format_date_time(%Date{} = d, nil), do: Calendar.strftime(d, "%b %d, %Y")

  defp format_date_time(%Date{} = d, %DateTime{} = dt) do
    Calendar.strftime(d, "%b %d, %Y") <> " " <> Calendar.strftime(dt, "%H:%M")
  end

  defp format_stat(nil), do: "—"
  defp format_stat(value) when is_float(value), do: round(value)
  defp format_stat(value), do: value

  defp format_expansions([]), do: "Base"

  defp format_expansions(expansions) do
    extra = Enum.reject(expansions, &(&1 == :base))

    if extra == [],
      do: "Base",
      else: Enum.map_join(extra, ", ", &String.capitalize(to_string(&1)))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="space-y-8">
        <%= case @mode do %>
          <% :home -> %>
            <div class="card bg-base-200 p-6">
              <h2 class="text-xl font-semibold mb-4">Your Stats</h2>
              <div class="grid grid-cols-2 sm:grid-cols-5 gap-3">
                <div class="bg-base-100 rounded-lg p-4 text-center">
                  <div class="text-2xl font-bold text-primary">
                    {format_stat(@user_stats.total_games)}
                  </div>
                  <div class="text-xs text-base-content/60 mt-1">Games Played</div>
                </div>
                <div class="bg-base-100 rounded-lg p-4 text-center">
                  <div class="text-2xl font-bold text-success">
                    {format_stat(@user_stats.games_won)}
                  </div>
                  <div class="text-xs text-base-content/60 mt-1">Games Won</div>
                </div>
                <div class="bg-base-100 rounded-lg p-4 text-center">
                  <div class="text-2xl font-bold">{format_stat(@user_stats.highest_score)}</div>
                  <div class="text-xs text-base-content/60 mt-1">Highest Score</div>
                </div>
                <div class="bg-base-100 rounded-lg p-4 text-center">
                  <div class="text-2xl font-bold">{format_stat(@user_stats.lowest_score)}</div>
                  <div class="text-xs text-base-content/60 mt-1">Lowest Score</div>
                </div>
                <div class="bg-base-100 rounded-lg p-4 text-center col-span-2 sm:col-span-1">
                  <div class="text-2xl font-bold">{format_stat(@user_stats.average_score)}</div>
                  <div class="text-xs text-base-content/60 mt-1">Average Score</div>
                </div>
              </div>
            </div>

            <div class="card bg-base-200 p-6">
              <h2 class="text-xl font-semibold mb-4">Games</h2>
              <%= if @games == [] do %>
                <p class="text-base-content/70 mb-4">No games in progress. Start a new game!</p>
              <% else %>
                <div class="space-y-2 mb-4">
                  <%= for game <- @games do %>
                    <div class="flex items-center justify-between bg-base-100 rounded p-3">
                      <span class="text-sm">
                        {if game.played_at,
                          do: Calendar.strftime(game.played_at, "%b %d, %Y"),
                          else: "In progress"}
                      </span>
                      <button
                        class="btn btn-sm btn-secondary"
                        phx-click="resume_game"
                        phx-value-game-id={game.id}
                      >
                        Resume
                      </button>
                    </div>
                  <% end %>
                </div>
              <% end %>
              <button class="btn btn-primary" phx-click="new_game">New Game</button>
            </div>

            <div class="card bg-base-200 p-6">
              <h2 class="text-xl font-semibold mb-4">Game History</h2>
              <Cinder.collection
                id="game-history"
                resource={WingspanScorer.Games.Game}
                action={:list_my_completed_games}
                actor={@current_user}
                url_state={false}
                show_filters={false}
                empty_message="No completed games yet."
              >
                <:col :let={game} field="played_at" sort label="Date">
                  {format_date_time(game.played_at, game.inserted_at)}
                </:col>
                <:col :let={game} field="expansions" label="Expansions">
                  {format_expansions(game.expansions)}
                </:col>
                <:col :let={game} field="player_count" label="Players">
                  {game.player_count}
                </:col>
              </Cinder.collection>
            </div>
          <% :setup -> %>
            <div class="card bg-base-200 p-6">
              <h2 class="text-xl font-semibold mb-4">New Game Setup</h2>
              <div class="space-y-6">
                <div>
                  <h3 class="text-lg font-semibold mb-2">Expansions</h3>
                  <div class="space-y-2">
                    <label class="flex items-center gap-2 cursor-not-allowed opacity-70">
                      <input type="checkbox" class="checkbox" checked disabled />
                      <span>Base (always included)</span>
                    </label>
                    <%= for {key, label} <- expansion_options() do %>
                      <label class="flex items-center gap-2 cursor-pointer">
                        <input
                          type="checkbox"
                          class="checkbox"
                          checked={key in @setup_expansions}
                          phx-click="toggle_expansion"
                          phx-value-expansion={key}
                        />
                        <span>{label}</span>
                      </label>
                    <% end %>
                  </div>
                </div>

                <div>
                  <h3 class="text-lg font-semibold mb-2">Players</h3>
                  <div class="space-y-2">
                    <div class="flex items-center gap-2 bg-base-100 rounded px-3 py-2">
                      <span>{@current_user.name || @current_user.email} (You)</span>
                    </div>

                    <%= for friend_id <- @setup_selected_friend_ids do %>
                      <% friendship = find_friendship(@setup_friendships, friend_id) %>
                      <%= if friendship do %>
                        <div class="flex items-center justify-between bg-base-100 rounded px-3 py-2">
                          <span>{friend_display_name(friendship)}</span>
                          <button
                            type="button"
                            class="btn btn-ghost btn-xs"
                            phx-click="remove_friend"
                            phx-value-friend-id={friend_id}
                          >
                            ✕
                          </button>
                        </div>
                      <% end %>
                    <% end %>

                    <%= for {name, i} <- Enum.with_index(@setup_guest_names) do %>
                      <div class="flex items-center justify-between bg-base-100 rounded px-3 py-2">
                        <span>{name} (Guest)</span>
                        <button
                          type="button"
                          class="btn btn-ghost btn-xs"
                          phx-click="remove_guest"
                          phx-value-index={i}
                        >
                          ✕
                        </button>
                      </div>
                    <% end %>
                  </div>
                </div>

                <%= if @setup_friendships != [] do %>
                  <div>
                    <button
                      type="button"
                      class="btn btn-outline btn-sm mb-3"
                      phx-click="toggle_friend_form"
                    >
                      + Add Friend
                    </button>

                    <%= if @show_friend_form do %>
                      <div class="bg-base-100 rounded p-4 space-y-3">
                        <h4 class="font-medium text-sm">Select friends to add</h4>
                        <div class="space-y-2">
                          <%= for friendship <- @setup_friendships do %>
                            <% already_added = friendship.friend_id in @setup_selected_friend_ids %>
                            <label class="flex items-center gap-3 cursor-pointer">
                              <input
                                type="checkbox"
                                class="checkbox checkbox-sm"
                                checked={already_added}
                                phx-click={
                                  if already_added, do: "remove_friend", else: "add_single_friend"
                                }
                                phx-value-friend-id={friendship.friend_id}
                              />
                              <span class={already_added && "line-through opacity-60"}>
                                {friend_display_name(friendship)}
                              </span>
                            </label>
                          <% end %>
                        </div>
                        <button
                          type="button"
                          class="btn btn-sm btn-ghost"
                          phx-click="toggle_friend_form"
                        >
                          Done
                        </button>
                      </div>
                    <% end %>
                  </div>
                <% end %>

                <form phx-submit="add_guest" class="space-y-1">
                  <div class="flex gap-2 items-center">
                    <input
                      type="text"
                      name="guest_name"
                      value={@setup_guest_input}
                      class={["input input-bordered input-sm", @setup_guest_error && "input-error"]}
                      placeholder="Guest name"
                    />
                    <button type="submit" class="btn btn-outline btn-sm">+ Add Guest</button>
                  </div>
                  <%= if @setup_guest_error do %>
                    <p class="text-error text-xs">{@setup_guest_error}</p>
                  <% end %>
                </form>

                <div class="flex gap-3">
                  <button class="btn btn-primary" phx-click="start_game">Start Game</button>
                  <button class="btn btn-ghost" phx-click="cancel_setup">Cancel</button>
                </div>
              </div>
            </div>
          <% :scoring -> %>
            <div class="card bg-base-200 p-6">
              <h2 class="text-xl font-semibold mb-4">Game in Progress</h2>
              <.live_component
                module={WingspanScorerWeb.ScoringFormComponent}
                id="scoring-form"
                game={@game}
                players={@players}
                current_user={@current_user}
                read_only={false}
              />
            </div>
          <% :results -> %>
            <div class="card bg-base-200 p-6">
              <h2 class="text-xl font-semibold mb-4">Game Saved!</h2>
              <p class="text-base-content/70 mb-4">
                Your game has been saved and will appear in your history.
              </p>
              <.live_component
                module={WingspanScorerWeb.ScoringFormComponent}
                id="results-form"
                game={@game}
                players={@players}
                current_user={@current_user}
                read_only={true}
              />
              <div class="mt-6">
                <button class="btn btn-primary" phx-click="back_to_home">Back to Home</button>
              </div>
            </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
