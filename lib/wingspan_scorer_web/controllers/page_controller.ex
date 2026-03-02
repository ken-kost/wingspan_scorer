defmodule WingspanScorerWeb.PageController do
  use WingspanScorerWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
