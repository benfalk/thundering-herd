defmodule ThunderingHerd.Batch do
  defmacro batch_size(batch) do
    quote do
      map_size(elem(unquote(batch), 0))
    end
  end

  def new, do: %{}

  def new(ref, item), do: %{item => [ref]}

  def add_data(data, ref, item) do
    {:ok, ref, Map.update(data, item, [ref], &[ref | &1])}
  end

  def process(data, func) do
    func.(data_to_process(data))
    |> Enum.flat_map(fn {key, val} ->
      Enum.map(data[key], &{&1, val})
    end)
  end

  ## Private Functions

  defp data_to_process(data), do: Map.keys(data)
end
