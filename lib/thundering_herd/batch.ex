defmodule ThunderingHerd.Batch do
  def new, do: %{}

  def new(ref, item), do: %{item => [ref]}

  def add_data(data, ref, item) do
    {:ok, Map.update(data, item, [ref], &[ref | &1])}
  end

  def process(data, func) do
    func.(items(data))
    |> Enum.flat_map(fn {key, val} ->
      Enum.map(data[key], &{&1, val})
    end)
  end

  def size(batch), do: map_size(batch)

  def items(data), do: Map.keys(data)
end
