defmodule WingspanScorer.Accounts.Calculations.UserStats do
  use Ash.Resource.Calculation

  @impl true
  def load(_query, _opts, _context), do: []

  @impl true
  def calculate(records, opts, _context) do
    stat = opts[:stat]
    user_ids = Enum.map(records, & &1.id)

    import Ecto.Query

    base_query =
      from(gp in "game_players",
        join: g in "games",
        on: g.id == gp.game_id,
        where: gp.user_id in ^user_ids and g.completed == true,
        group_by: gp.user_id
      )

    results =
      case stat do
        :total_games ->
          base_query
          |> select([gp], {gp.user_id, count(gp.id)})
          |> WingspanScorer.Repo.all()
          |> Map.new()

        :games_won ->
          base_query
          |> where([gp], gp.is_winner == true)
          |> select([gp], {gp.user_id, count(gp.id)})
          |> WingspanScorer.Repo.all()
          |> Map.new()

        :highest_score ->
          base_query
          |> select([gp], {gp.user_id, max(gp.bird_points + gp.bonus_card_points + gp.end_of_round_goals + gp.eggs + gp.cached_food + gp.tucked_cards + gp.nectar_forest + gp.nectar_grassland + gp.nectar_wetland + gp.duet_map_points + gp.hummingbird_points)})
          |> WingspanScorer.Repo.all()
          |> Map.new()

        :lowest_score ->
          base_query
          |> select([gp], {gp.user_id, min(gp.bird_points + gp.bonus_card_points + gp.end_of_round_goals + gp.eggs + gp.cached_food + gp.tucked_cards + gp.nectar_forest + gp.nectar_grassland + gp.nectar_wetland + gp.duet_map_points + gp.hummingbird_points)})
          |> WingspanScorer.Repo.all()
          |> Map.new()

        :average_score ->
          base_query
          |> select([gp], {gp.user_id, avg(gp.bird_points + gp.bonus_card_points + gp.end_of_round_goals + gp.eggs + gp.cached_food + gp.tucked_cards + gp.nectar_forest + gp.nectar_grassland + gp.nectar_wetland + gp.duet_map_points + gp.hummingbird_points)})
          |> WingspanScorer.Repo.all()
          |> Map.new()
      end

    Enum.map(records, fn record ->
      Map.get(results, record.id)
    end)
  end
end
