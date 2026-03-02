defmodule WingspanScorer.Accounts do
  use Ash.Domain, otp_app: :wingspan_scorer, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource WingspanScorer.Accounts.Token
    resource WingspanScorer.Accounts.User
  end
end
