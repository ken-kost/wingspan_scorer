defmodule WingspanScorer.Games.Calculations.PlayerCount do
  use Ash.Resource.Calculation

  @impl true
  def load(_query, _opts, _context) do
    []
  end

  @impl true
  def calculate(records, _opts, _context) do
    game_ids = Enum.map(records, & &1.id)

    import Ecto.Query

    counts =
      from(gp in "game_players",
        where: gp.game_id in ^game_ids,
        group_by: gp.game_id,
        select: {gp.game_id, count(gp.id)}
      )
      |> WingspanScorer.Repo.all()
      |> Map.new()

    Enum.map(records, fn record ->
      Map.get(counts, record.id, 0)
    end)
  end
end
