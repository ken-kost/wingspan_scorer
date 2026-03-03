defmodule WingspanScorer.Games.GamePlayer do
  use Ash.Resource,
    otp_app: :wingspan_scorer,
    domain: WingspanScorer.Games,
    data_layer: Ash.DataLayer.Mnesia,
    authorizers: [Ash.Policy.Authorizer]

  mnesia do
    table :game_players
  end

  actions do
    read :read do
      primary? true
    end

    create :create do
      accept [
        :bird_points,
        :bonus_card_points,
        :end_of_round_goals,
        :eggs,
        :cached_food,
        :tucked_cards,
        :nectar_forest,
        :nectar_grassland,
        :nectar_wetland,
        :duet_map_points,
        :hummingbird_points,
        :guest_name,
        :game_id,
        :user_id
      ]
    end

    update :update_scores do
      accept [
        :bird_points,
        :bonus_card_points,
        :end_of_round_goals,
        :eggs,
        :cached_food,
        :tucked_cards,
        :nectar_forest,
        :nectar_grassland,
        :nectar_wetland,
        :duet_map_points,
        :hummingbird_points
      ]
    end

    update :mark_winner do
      accept []
      change set_attribute(:is_winner, true)
    end
  end

  policies do
    policy action_type(:create) do
      authorize_if actor_present()
    end

    policy action_type(:read) do
      authorize_if expr(exists(game.game_players, user_id == ^actor(:id)))
      authorize_if expr(game.creator_id == ^actor(:id))
    end

    policy action(:update_scores) do
      authorize_if expr(game.creator_id == ^actor(:id))
    end

    policy action(:mark_winner) do
      authorize_if expr(game.creator_id == ^actor(:id))
    end
  end

  validations do
    validate compare(:bird_points, greater_than_or_equal_to: 0)
    validate compare(:bonus_card_points, greater_than_or_equal_to: 0)
    validate compare(:end_of_round_goals, greater_than_or_equal_to: 0)
    validate compare(:eggs, greater_than_or_equal_to: 0)
    validate compare(:cached_food, greater_than_or_equal_to: 0)
    validate compare(:tucked_cards, greater_than_or_equal_to: 0)
    validate compare(:nectar_forest, greater_than_or_equal_to: 0)
    validate compare(:nectar_grassland, greater_than_or_equal_to: 0)
    validate compare(:nectar_wetland, greater_than_or_equal_to: 0)
    validate compare(:duet_map_points, greater_than_or_equal_to: 0)
    validate compare(:hummingbird_points, greater_than_or_equal_to: 0)
  end

  attributes do
    uuid_primary_key :id

    attribute :bird_points, :integer do
      default 0
      public? true
    end

    attribute :bonus_card_points, :integer do
      default 0
      public? true
    end

    attribute :end_of_round_goals, :integer do
      default 0
      public? true
    end

    attribute :eggs, :integer do
      default 0
      public? true
    end

    attribute :cached_food, :integer do
      default 0
      public? true
    end

    attribute :tucked_cards, :integer do
      default 0
      public? true
    end

    attribute :nectar_forest, :integer do
      default 0
      public? true
    end

    attribute :nectar_grassland, :integer do
      default 0
      public? true
    end

    attribute :nectar_wetland, :integer do
      default 0
      public? true
    end

    attribute :duet_map_points, :integer do
      default 0
      public? true
    end

    attribute :hummingbird_points, :integer do
      default 0
      public? true
    end

    attribute :guest_name, :string do
      allow_nil? true
      public? true
    end

    attribute :is_winner, :boolean do
      default false
      public? true
    end
  end

  relationships do
    belongs_to :game, WingspanScorer.Games.Game do
      allow_nil? false
      public? true
    end

    belongs_to :user, WingspanScorer.Accounts.User do
      allow_nil? true
      public? true
    end
  end

  calculations do
    calculate :display_name,
              :string,
              expr(
                if not is_nil(user_id) do
                  user.name
                else
                  guest_name
                end
              )

    calculate :base_total,
              :integer,
              expr(
                bird_points + bonus_card_points + end_of_round_goals +
                  eggs + cached_food + tucked_cards +
                  nectar_forest + nectar_grassland + nectar_wetland +
                  duet_map_points + hummingbird_points
              )
  end
end
