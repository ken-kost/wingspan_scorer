defmodule WingspanScorer.Games do
  use Ash.Domain, otp_app: :wingspan_scorer

  resources do
    resource WingspanScorer.Games.Game do
      define :create_game, action: :create
      define :get_game, action: :read, get_by: [:id]
      define :list_my_games, action: :list_my_games
      define :list_user_completed_games, action: :list_user_completed_games, args: [:user_id]
      define :complete_game, action: :complete
    end

    resource WingspanScorer.Games.GamePlayer do
      define :create_game_player, action: :create
      define :update_game_player_scores, action: :update_scores
      define :mark_game_player_winner, action: :mark_winner
    end
  end
end
