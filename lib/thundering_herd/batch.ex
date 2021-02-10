defmodule ThunderingHerd.Batch do
  @typedoc """
  A batch is a map where each key is the data to
  be worked on and the value is a list of callers
  that want to be notified of the result
  """
  @type t :: %{any() => [GenServer.from(), ...]}

  @typedoc """
  A function that receives a list of terms and
  returns a map.  Each key is from the orginal
  list and it's value is the result that will
  eventually be sent to the upstream caller.
  """
  @type process_fun :: ([any()] -> %{any() => any()})

  @spec new() :: t()
  def new, do: %{}

  @spec new(GenServer.from(), any()) :: t()
  def new(ref, item), do: %{item => [ref]}

  @spec add_data(t(), GenServer.from(), any()) :: {:ok, t()}
  def add_data(batch, ref, data) do
    {:ok, Map.update(batch, data, [ref], &[ref | &1])}
  end

  @spec process(t(), process_fun()) :: [{GenServer.from(), any()}]
  def process(batch, func) do
    func.(items(batch))
    |> Enum.flat_map(fn {key, val} ->
      Enum.map(batch[key], &{&1, val})
    end)
  end

  @spec size(t()) :: non_neg_integer()
  def size(batch), do: map_size(batch)

  @spec items(t()) :: [any()]
  def items(batch), do: Map.keys(batch)
end
