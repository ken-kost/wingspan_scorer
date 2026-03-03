defmodule WingspanScorer.Accounts.Changes.DestroyReverseFriendship do
  use Ash.Resource.Change

  require Ash.Query

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, record ->
      reverse_user_id = record.friend_id
      reverse_friend_id = record.user_id

      case WingspanScorer.Accounts.Friendship
           |> Ash.Query.filter(user_id == ^reverse_user_id and friend_id == ^reverse_friend_id)
           |> Ash.read_one(authorize?: false) do
        {:ok, nil} ->
          {:ok, record}

        {:ok, reverse} ->
          reverse
          |> Ash.Changeset.for_destroy(:destroy_reverse)
          |> Ash.destroy(authorize?: false)
          |> case do
            :ok -> {:ok, record}
            {:error, error} -> {:error, error}
          end

        {:error, error} ->
          {:error, error}
      end
    end)
  end
end
