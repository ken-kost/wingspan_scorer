defmodule WingspanScorer.Accounts.User do
  use Ash.Resource,
    otp_app: :wingspan_scorer,
    domain: WingspanScorer.Accounts,
    data_layer: Ash.DataLayer.Mnesia,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAuthentication]

  require Ash.Query

  mnesia do
    table :users
  end

  authentication do
    add_ons do
      log_out_everywhere do
        apply_on_password_change? true
      end
    end

    tokens do
      enabled? true
      token_resource WingspanScorer.Accounts.Token
      signing_secret WingspanScorer.Secrets
      store_all_tokens? true
      require_token_presence_for_authentication? true
    end

    strategies do
      password :password do
        identity_field :email
        hashed_password_field :hashed_password
        confirmation_required? false
      end

      remember_me :remember_me
    end
  end

  actions do
    defaults [:read]

    read :get_by_subject do
      description "Get a user by the subject claim in a JWT"
      argument :subject, :string, allow_nil?: false
      get? true
      prepare AshAuthentication.Preparations.FilterBySubject
    end

    read :get_by_email do
      description "Looks up a user by their email"
      get_by :email
    end

    read :search do
      argument :query, :string, allow_nil?: false

      prepare fn query, _context ->
        search = Ash.Query.get_argument(query, :query)
        pattern = "%#{search}%"
        Ash.Query.filter(query, contains(email, ^search) or contains(name, ^search))
      end
    end

    update :update_profile do
      accept [:name]
      require_atomic? false
    end
  end

  policies do
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if always()
    end

    policy action(:search) do
      authorize_if actor_present()
    end

    policy action(:update_profile) do
      authorize_if expr(id == ^actor(:id))
    end

    policy action_type(:read) do
      authorize_if actor_present()
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :email, :ci_string do
      allow_nil? false
      public? true
    end

    attribute :name, :string do
      allow_nil? true
      public? true
    end

    attribute :hashed_password, :string do
      allow_nil? false
      sensitive? true
    end
  end

  relationships do
    has_many :friendships, WingspanScorer.Accounts.Friendship

    many_to_many :friends, WingspanScorer.Accounts.User do
      through WingspanScorer.Accounts.Friendship
      source_attribute_on_join_resource :user_id
      destination_attribute_on_join_resource :friend_id
    end

    has_many :game_players, WingspanScorer.Games.GamePlayer
  end

  aggregates do
    count :total_games, :game_players do
      filter expr(game.completed == true)
    end

    count :games_won, :game_players do
      filter expr(game.completed == true and is_winner == true)
    end

    max :highest_score, :game_players, :base_total do
      filter expr(game.completed == true)
    end

    min :lowest_score, :game_players, :base_total do
      filter expr(game.completed == true)
    end

    avg :average_score, :game_players, :base_total do
      filter expr(game.completed == true)
    end
  end

  identities do
    identity :unique_email, [:email], pre_check_with: WingspanScorer.Accounts
  end
end
