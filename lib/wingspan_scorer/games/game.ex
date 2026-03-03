defmodule WingspanScorer.Games.Game do
  use Ash.Resource,
    otp_app: :wingspan_scorer,
    domain: WingspanScorer.Games,
    data_layer: Ash.DataLayer.Mnesia,
    authorizers: [Ash.Policy.Authorizer]

  mnesia do
    table :games
  end

  actions do
    read :read do
      primary? true
    end

    read :list_my_games do
      prepare build(sort: [played_at: :desc])

      filter expr(
               creator_id == ^actor(:id) or
                 exists(game_players, user_id == ^actor(:id))
             )
    end

    read :list_my_completed_games do
      prepare build(sort: [played_at: :desc], load: [:player_count])

      filter expr(
               completed == true and
                 (creator_id == ^actor(:id) or exists(game_players, user_id == ^actor(:id)))
             )
    end

    read :list_user_completed_games do
      argument :user_id, :uuid, allow_nil?: false

      prepare build(sort: [inserted_at: :desc], load: [:player_count, game_players: [:user]])

      filter expr(
               completed == true and
                 (creator_id == ^arg(:user_id) or exists(game_players, user_id == ^arg(:user_id)))
             )
    end

    create :create do
      accept [:expansions, :played_at]
      change relate_actor(:creator)
    end

    update :complete do
      accept []
      change set_attribute(:completed, true)
    end

    destroy :destroy do
      primary? true
    end
  end

  policies do
    policy action_type(:create) do
      authorize_if actor_present()
    end

    policy action(:list_my_games) do
      authorize_if actor_present()
    end

    policy action(:list_my_completed_games) do
      authorize_if actor_present()
    end

    policy action(:list_user_completed_games) do
      authorize_if actor_present()
    end

    policy action(:read) do
      authorize_if expr(creator_id == ^actor(:id))
      authorize_if expr(exists(game_players, user_id == ^actor(:id)))
    end

    policy action(:complete) do
      authorize_if expr(creator_id == ^actor(:id))
    end

    policy action(:destroy) do
      authorize_if expr(creator_id == ^actor(:id))
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :expansions, {:array, :atom} do
      default []
      public? true
      constraints items: [one_of: [:base, :european, :oceania, :asia, :americas]]
    end

    attribute :played_at, :date do
      allow_nil? true
      public? true
    end

    attribute :completed, :boolean do
      default false
      public? true
    end

    create_timestamp :inserted_at
  end

  relationships do
    belongs_to :creator, WingspanScorer.Accounts.User do
      allow_nil? false
      public? true
    end

    has_many :game_players, WingspanScorer.Games.GamePlayer do
      public? true
    end
  end

  aggregates do
    count :player_count, :game_players
  end
end
