defmodule WingspanScorerWeb.ScoringFormComponent do
  use WingspanScorerWeb, :live_component

  alias WingspanScorer.Games

  @base_fields [
    {"bird_points", "Bird Points"},
    {"bonus_card_points", "Bonus Cards"},
    {"end_of_round_goals", "End-of-Round Goals"},
    {"eggs", "Eggs"},
    {"cached_food", "Cached Food"},
    {"tucked_cards", "Tucked Cards"}
  ]

  @nectar_fields [
    {"nectar_forest", "Nectar (Forest)"},
    {"nectar_grassland", "Nectar (Grassland)"},
    {"nectar_wetland", "Nectar (Wetland)"}
  ]

  @impl true
  def update(%{game: game, players: players} = assigns, socket) do
    socket = assign(socket, assigns)

    socket =
      if socket.assigns[:current_game_id] != game.id do
        assign(socket,
          scores: initialize_scores(players),
          current_game_id: game.id,
          save_error: nil
        )
      else
        socket
      end

    {:ok, socket}
  end

  @impl true
  def handle_event("update_scores", %{"scores" => raw_scores}, socket) do
    scores = parse_scores(raw_scores)
    update_all_scores(socket.assigns.players, scores, socket.assigns.current_user)
    {:noreply, assign(socket, scores: scores)}
  end

  def handle_event("update_scores", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("save_game", _params, socket) do
    %{game: game, players: players, scores: scores, current_user: user} = socket.assigns

    winner_ids = find_winner_ids(players, scores, game)

    with :ok <- update_all_scores(players, scores, user),
         :ok <- mark_game_winners(players, winner_ids, user),
         {:ok, _} <- Games.complete_game(game, actor: user) do
      send(self(), {:game_saved})
      {:noreply, socket}
    else
      {:error, _} ->
        {:noreply, assign(socket, save_error: "Failed to save game. Please try again.")}
    end
  end

  defp find_winner_ids(players, scores, game) do
    totals = Map.new(players, fn p -> {p.id, calculate_total(p.id, scores, game)} end)

    {_winner_id, max_total} =
      Enum.max_by(totals, fn {_, v} -> v end, fn -> {nil, 0} end)

    Enum.flat_map(totals, fn {id, total} -> if total == max_total, do: [id], else: [] end)
  end

  defp mark_game_winners(players, winner_ids, user) do
    Enum.reduce_while(players, :ok, fn player, :ok ->
      if player.id in winner_ids do
        case Games.mark_game_player_winner(player, actor: user) do
          {:ok, _} -> {:cont, :ok}
          {:error, e} -> {:halt, {:error, e}}
        end
      else
        {:cont, :ok}
      end
    end)
  end

  defp update_all_scores(players, scores, user) do
    Enum.reduce_while(players, :ok, fn player, :ok ->
      player_scores = Map.get(scores, player.id, %{})

      attrs = %{
        bird_points: get_score(player_scores, "bird_points"),
        bonus_card_points: get_score(player_scores, "bonus_card_points"),
        end_of_round_goals: get_score(player_scores, "end_of_round_goals"),
        eggs: get_score(player_scores, "eggs"),
        cached_food: get_score(player_scores, "cached_food"),
        tucked_cards: get_score(player_scores, "tucked_cards"),
        nectar_forest: get_score(player_scores, "nectar_forest"),
        nectar_grassland: get_score(player_scores, "nectar_grassland"),
        nectar_wetland: get_score(player_scores, "nectar_wetland"),
        duet_map_points: get_score(player_scores, "duet_map_points"),
        hummingbird_points: get_score(player_scores, "hummingbird_points")
      }

      case Games.update_game_player_scores(player, attrs, actor: user) do
        {:ok, _} -> {:cont, :ok}
        {:error, e} -> {:halt, {:error, e}}
      end
    end)
  end

  defp initialize_scores(players) do
    Map.new(players, fn player ->
      {player.id,
       %{
         "bird_points" => player.bird_points || 0,
         "bonus_card_points" => player.bonus_card_points || 0,
         "end_of_round_goals" => player.end_of_round_goals || 0,
         "eggs" => player.eggs || 0,
         "cached_food" => player.cached_food || 0,
         "tucked_cards" => player.tucked_cards || 0,
         "nectar_forest" => player.nectar_forest || 0,
         "nectar_grassland" => player.nectar_grassland || 0,
         "nectar_wetland" => player.nectar_wetland || 0,
         "duet_map_points" => player.duet_map_points || 0,
         "hummingbird_points" => player.hummingbird_points || 0
       }}
    end)
  end

  defp parse_scores(raw_scores) do
    Map.new(raw_scores, fn {player_id, field_map} ->
      parsed = Map.new(field_map, fn {k, v} -> {k, parse_int(v)} end)
      {player_id, parsed}
    end)
  end

  defp calculate_total(player_id, scores, game) do
    fields = Map.get(scores, player_id, %{})

    base =
      Enum.sum_by(
        [
          "bird_points",
          "bonus_card_points",
          "end_of_round_goals",
          "eggs",
          "cached_food",
          "tucked_cards"
        ],
        &get_score(fields, &1)
      )

    oceania =
      if :oceania in game.expansions do
        Enum.sum_by(
          ["nectar_forest", "nectar_grassland", "nectar_wetland"],
          &get_score(fields, &1)
        )
      else
        0
      end

    asia = if :asia in game.expansions, do: get_score(fields, "duet_map_points"), else: 0

    americas =
      if :americas in game.expansions, do: get_score(fields, "hummingbird_points"), else: 0

    base + oceania + asia + americas
  end

  defp player_display_name(player) do
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

  defp get_score(fields, key), do: parse_int(Map.get(fields, key, 0))

  defp parse_int(v) when is_integer(v), do: v

  defp parse_int(v) when is_binary(v) do
    case Integer.parse(v) do
      {n, _} -> max(0, n)
      :error -> 0
    end
  end

  defp parse_int(_), do: 0

  @impl true
  def render(assigns) do
    totals =
      Map.new(assigns.players, fn p ->
        {p.id, calculate_total(p.id, assigns.scores, assigns.game)}
      end)

    {winner_id, _} =
      totals
      |> Enum.max_by(fn {_, v} -> v end, fn -> {nil, 0} end)

    assigns =
      assign(assigns,
        totals: totals,
        winner_id: winner_id,
        base_fields: @base_fields,
        nectar_fields: @nectar_fields
      )

    ~H"""
    <div>
      <%= if @save_error do %>
        <div class="alert alert-error mb-4">{@save_error}</div>
      <% end %>

      <form phx-change="update_scores" phx-target={@myself} class="overflow-x-auto">
        <table class="table table-sm w-full">
          <thead>
            <tr>
              <th class="w-44">Category</th>
              <%= for player <- @players do %>
                <th class={[
                  "text-center",
                  player.id == @winner_id && "text-primary font-bold"
                ]}>
                  {player_display_name(player)}
                  <%= if player.id == @winner_id do %>
                    <span class="ml-1">🏆</span>
                  <% end %>
                </th>
              <% end %>
            </tr>
          </thead>
          <tbody>
            <%= for {field, label} <- @base_fields do %>
              <tr>
                <td class="font-medium">{label}</td>
                <%= for player <- @players do %>
                  <td class="text-center">
                    <%= if @read_only do %>
                      {get_score(Map.get(@scores, player.id, %{}), field)}
                    <% else %>
                      <input
                        type="number"
                        name={"scores[#{player.id}][#{field}]"}
                        value={get_score(Map.get(@scores, player.id, %{}), field)}
                        min="0"
                        class="input input-bordered input-sm w-20 text-center"
                        phx-debounce="200"
                      />
                    <% end %>
                  </td>
                <% end %>
              </tr>
            <% end %>

            <%= if :oceania in @game.expansions do %>
              <%= for {field, label} <- @nectar_fields do %>
                <tr>
                  <td class="font-medium">{label}</td>
                  <%= for player <- @players do %>
                    <td class="text-center">
                      <%= if @read_only do %>
                        {get_score(Map.get(@scores, player.id, %{}), field)}
                      <% else %>
                        <input
                          type="number"
                          name={"scores[#{player.id}][#{field}]"}
                          value={get_score(Map.get(@scores, player.id, %{}), field)}
                          min="0"
                          class="input input-bordered input-sm w-20 text-center"
                          phx-debounce="200"
                        />
                      <% end %>
                    </td>
                  <% end %>
                </tr>
              <% end %>
            <% end %>

            <%= if :asia in @game.expansions do %>
              <tr>
                <td class="font-medium">Duet Map Points</td>
                <%= for player <- @players do %>
                  <td class="text-center">
                    <%= if @read_only do %>
                      {get_score(Map.get(@scores, player.id, %{}), "duet_map_points")}
                    <% else %>
                      <input
                        type="number"
                        name={"scores[#{player.id}][duet_map_points]"}
                        value={get_score(Map.get(@scores, player.id, %{}), "duet_map_points")}
                        min="0"
                        class="input input-bordered input-sm w-20 text-center"
                        phx-debounce="200"
                      />
                    <% end %>
                  </td>
                <% end %>
              </tr>
            <% end %>

            <%= if :americas in @game.expansions do %>
              <tr>
                <td class="font-medium">Hummingbird Points</td>
                <%= for player <- @players do %>
                  <td class="text-center">
                    <%= if @read_only do %>
                      {get_score(Map.get(@scores, player.id, %{}), "hummingbird_points")}
                    <% else %>
                      <input
                        type="number"
                        name={"scores[#{player.id}][hummingbird_points]"}
                        value={get_score(Map.get(@scores, player.id, %{}), "hummingbird_points")}
                        min="0"
                        class="input input-bordered input-sm w-20 text-center"
                        phx-debounce="200"
                      />
                    <% end %>
                  </td>
                <% end %>
              </tr>
            <% end %>

            <tr class="border-t-2">
              <td class="font-bold text-base">Total</td>
              <%= for player <- @players do %>
                <td class={[
                  "text-center text-lg font-bold",
                  player.id == @winner_id && "text-primary"
                ]}>
                  {Map.get(@totals, player.id, 0)}
                </td>
              <% end %>
            </tr>
          </tbody>
        </table>
      </form>

      <%= if !@read_only do %>
        <div class="mt-6">
          <button
            type="button"
            class="btn btn-primary"
            phx-click="save_game"
            phx-target={@myself}
          >
            Save Game
          </button>
        </div>
      <% end %>
    </div>
    """
  end
end
