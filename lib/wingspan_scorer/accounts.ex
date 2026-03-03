defmodule WingspanScorer.Accounts do
  use Ash.Domain, otp_app: :wingspan_scorer, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource WingspanScorer.Accounts.Token

    resource WingspanScorer.Accounts.User do
      define :get_user, action: :read, get_by: [:id]
      define :update_user_profile, action: :update_profile
      define :search_users, action: :search, args: [:query]
    end

    resource WingspanScorer.Accounts.Friendship do
      define :add_friend, action: :create, args: [:friend_id]
      define :remove_friend, action: :destroy
      define :list_my_friendships, action: :read
    end
  end
end
