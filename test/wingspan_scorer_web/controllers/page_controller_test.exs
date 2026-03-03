defmodule WingspanScorerWeb.DashboardLiveAuthTest do
  use WingspanScorerWeb.ConnCase

  test "GET / redirects to sign-in when unauthenticated", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn) == ~p"/sign-in"
  end
end
