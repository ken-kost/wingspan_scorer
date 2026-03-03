defmodule WingspanScorer.Accounts.Token.IsRevoked do
  @moduledoc """
  Custom IsRevoked implementation that works with the Mnesia data layer.

  The default AshAuthentication.TokenResource.IsRevoked uses Ash.exists/1 which
  returns `{:ok, %{exists: false}}` with Mnesia instead of `{:ok, boolean}`.
  This implementation uses Ash.read/1 instead.
  """
  use Ash.Resource.Actions.Implementation

  @impl true
  def run(input, _opts, _context) do
    jti =
      case input.arguments do
        %{jti: jti} when is_binary(jti) ->
          jti

        %{token: token} when is_binary(token) ->
          case AshAuthentication.Jwt.peek(token) do
            {:ok, %{"jti" => jti}} -> jti
            _ -> nil
          end

        _ ->
          nil
      end

    if jti do
      result =
        input.resource
        |> Ash.Query.do_filter(purpose: "revocation", jti: jti)
        |> Ash.Query.set_context(%{private: %{ash_authentication?: true}})
        |> Ash.read()

      case result do
        {:ok, []} -> {:ok, false}
        {:ok, _} -> {:ok, true}
        {:error, _} -> {:ok, true}
      end
    else
      {:ok, false}
    end
  end
end
