defmodule ThunderingHerd.Batch do
  defmacro size(batch) do
    quote do
      map_size(unquote(batch))
    end
  end

  defmacro empty?(batch) do
    quote do
      map_size(unquote(batch)) == 0
    end
  end

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

  def items(data), do: Map.keys(data)
end
