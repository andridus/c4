defmodule C4.Helpers.Web do
  @moduledoc false
  def get_paths(uri, params \\ %{}) do
    %URI{path: path} = URI.parse(uri)

    {current, previous} =
      String.split(path, "/")
      |> Enum.reverse()
      |> case do
        [current_page, ""] -> {current_page, nil}
        [current_page | previous] -> {current_page, previous |> Enum.reverse() |> Enum.join("/")}
        [] -> {path, nil}
      end

    %{
      path: path,
      current_page: current,
      previous: previous |> maybe_with_id(params),
      path_params: params
    }
  end

  defp maybe_with_id(previous, %{"id" => id}) do
    previous
    |> String.replace_suffix("/#{id}", "")
  end

  defp maybe_with_id(previous, _params), do: previous
end
