defmodule WingspanScorerWeb.SettingsLive do
  use WingspanScorerWeb, :live_view

  alias WingspanScorer.Accounts

  on_mount {WingspanScorerWeb.LiveUserAuth, :live_user_required}

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    form = build_profile_form(user)
    {:ok, assign(socket, form: form)}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("validate_profile", %{"form" => params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, params)
    {:noreply, assign(socket, :form, form)}
  end

  @impl true
  def handle_event("save_profile", %{"form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, user} ->
        form = build_profile_form(user)

        {:noreply,
         socket
         |> assign(form: form, current_user: user)
         |> put_flash(:info, "Profile updated!")}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  defp build_profile_form(user) do
    user
    |> AshPhoenix.Form.for_update(:update_profile,
      domain: Accounts,
      actor: user
    )
    |> to_form()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="space-y-8">
        <div class="card bg-base-200 p-6 max-w-sm">
          <h2 class="text-xl font-semibold mb-4">Settings</h2>
          <h3 class="text-base font-medium mb-3">Display Name</h3>
          <.form for={@form} phx-change="validate_profile" phx-submit="save_profile">
            <div class="flex flex-col gap-4">
              <.input
                field={@form[:name]}
                label="Display Name"
                placeholder="Enter your name"
              />
              <div>
                <.button type="submit" class="btn btn-primary">Save</.button>
              </div>
            </div>
          </.form>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
