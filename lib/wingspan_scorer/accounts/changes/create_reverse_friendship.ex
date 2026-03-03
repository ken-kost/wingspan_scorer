defmodule WingspanScorer.Accounts.Changes.CreateReverseFriendship do
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, record ->
      WingspanScorer.Accounts.Friendship
      |> Ash.Changeset.for_create(:create_reverse, %{
        user_id: record.friend_id,
        friend_id: record.user_id
      })
      |> Ash.create(
        authorize?: false,
        upsert?: true,
        upsert_identity: :unique_friendship
      )
      |> case do
        {:ok, _} -> {:ok, record}
        {:error, error} -> {:error, error}
      end
    end)
  end
end
