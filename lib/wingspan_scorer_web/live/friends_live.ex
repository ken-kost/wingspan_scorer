defmodule WingspanScorerWeb.FriendsLive do
  use WingspanScorerWeb, :live_view

  alias WingspanScorer.Accounts

  on_mount {WingspanScorerWeb.LiveUserAuth, :live_user_required}

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    friendships = load_friendships(user)

    {:ok,
     assign(socket,
       friendships: friendships,
       search_results: [],
       search_query: ""
     )}
  end

  @impl true
  def handle_event("search", %{"query" => ""}, socket) do
    {:noreply, assign(socket, search_results: [], search_query: "")}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    user = socket.assigns.current_user
    friend_ids = MapSet.new(socket.assigns.friendships, & &1.friend_id)

    results =
      case Accounts.search_users(query, actor: user) do
        {:ok, users} ->
          users
          |> Enum.reject(&(&1.id == user.id))
          |> Enum.reject(&MapSet.member?(friend_ids, &1.id))

        {:error, _} ->
          []
      end

    {:noreply, assign(socket, search_results: results, search_query: query)}
  end

  @impl true
  def handle_event("add_friend", %{"friend-id" => friend_id}, socket) do
    user = socket.assigns.current_user

    case Accounts.add_friend(friend_id, actor: user) do
      {:ok, _} ->
        friendships = load_friendships(user)
        friend_ids = MapSet.new(friendships, & &1.friend_id)

        # Remove newly added friend from search results
        updated_results =
          Enum.reject(socket.assigns.search_results, &MapSet.member?(friend_ids, &1.id))

        {:noreply,
         socket
         |> assign(friendships: friendships, search_results: updated_results)
         |> put_flash(:info, "Friend added!")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not add friend.")}
    end
  end

  @impl true
  def handle_event("remove_friend", %{"id" => id}, socket) do
    user = socket.assigns.current_user
    friendship = Enum.find(socket.assigns.friendships, &(to_string(&1.id) == id))

    case friendship do
      nil ->
        {:noreply, put_flash(socket, :error, "Friend not found.")}

      friendship ->
        case Accounts.remove_friend(friendship, actor: user) do
          :ok ->
            friendships = load_friendships(user)

            {:noreply,
             socket
             |> assign(friendships: friendships)
             |> put_flash(:info, "Friend removed.")}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Could not remove friend.")}
        end
    end
  end

  defp load_friendships(user) do
    case Accounts.list_my_friendships(actor: user, load: [:friend]) do
      {:ok, friendships} -> friendships
      {:error, _} -> []
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="space-y-6">
        <div class="card bg-base-200 p-6">
          <h1 class="text-2xl font-bold mb-4">Friends</h1>

          <div class="mb-6">
            <h2 class="text-lg font-semibold mb-2">Find Friends</h2>
            <form phx-change="search" id="friend-search-form">
              <input
                type="text"
                class="input input-bordered w-full max-w-sm"
                placeholder="Search by name or email"
                value={@search_query}
                phx-debounce="300"
                name="query"
              />
            </form>
          </div>

          <%= if @search_results != [] do %>
            <div class="mb-6">
              <h3 class="text-sm font-medium text-base-content/70 mb-2">Search Results</h3>
              <ul class="space-y-2">
                <%= for user <- @search_results do %>
                  <li class="flex items-center justify-between bg-base-100 rounded p-3">
                    <span class="font-medium">{user.name || user.email}</span>
                    <button
                      class="btn btn-sm btn-primary"
                      phx-click="add_friend"
                      phx-value-friend-id={user.id}
                    >
                      Befriend
                    </button>
                  </li>
                <% end %>
              </ul>
            </div>
          <% end %>

          <div>
            <h2 class="text-lg font-semibold mb-2">My Friends ({length(@friendships)})</h2>
            <%= if @friendships == [] do %>
              <p class="text-base-content/70">No friends yet. Search above to add some!</p>
            <% else %>
              <ul class="space-y-2">
                <%= for friendship <- @friendships do %>
                  <li class="flex items-center justify-between bg-base-100 rounded p-3">
                    <.link
                      navigate={~p"/friends/#{friendship.friend_id}"}
                      class="font-medium hover:text-primary transition-colors"
                    >
                      {friendship.friend.name || friendship.friend.email}
                    </.link>
                    <button
                      class="btn btn-sm btn-outline btn-error"
                      phx-click="remove_friend"
                      phx-value-id={friendship.id}
                    >
                      Remove
                    </button>
                  </li>
                <% end %>
              </ul>
            <% end %>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
