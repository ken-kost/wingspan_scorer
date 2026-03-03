defmodule WingspanScorer.Accounts.Friendship do
  use Ash.Resource,
    otp_app: :wingspan_scorer,
    domain: WingspanScorer.Accounts,
    data_layer: Ash.DataLayer.Mnesia,
    authorizers: [Ash.Policy.Authorizer]

  mnesia do
    table :friendships
  end

  actions do
    read :read do
      primary? true
    end

    create :create do
      accept [:friend_id]
      change relate_actor(:user)
      change WingspanScorer.Accounts.Changes.CreateReverseFriendship
    end

    create :create_reverse do
      accept [:user_id, :friend_id]
    end

    destroy :destroy do
      primary? true
      require_atomic? false
      change WingspanScorer.Accounts.Changes.DestroyReverseFriendship
    end

    destroy :destroy_reverse do
      # Used internally by DestroyReverseFriendship; no cascade
    end
  end

  policies do
    policy action(:create) do
      authorize_if actor_present()
    end

    policy action(:destroy) do
      authorize_if expr(user_id == ^actor(:id))
    end

    policy action_type(:read) do
      authorize_if expr(user_id == ^actor(:id))
    end
  end

  attributes do
    uuid_primary_key :id
  end

  relationships do
    belongs_to :user, WingspanScorer.Accounts.User, allow_nil?: false, public?: true
    belongs_to :friend, WingspanScorer.Accounts.User, allow_nil?: false, public?: true
  end

  identities do
    identity :unique_friendship, [:user_id, :friend_id], pre_check_with: WingspanScorer.Accounts
  end
end
