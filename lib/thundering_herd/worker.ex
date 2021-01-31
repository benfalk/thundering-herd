defmodule ThunderingHerd.Worker do
  use GenServer
  alias ThunderingHerd, as: TH
  import TH.Batch, only: [empty?: 1]

  defstruct working: false,
            batch: TH.Batch.new(),
            func: nil

  def start_link(batching_work_fun \\ &TH.Worker.simple_echo/1) do
    GenServer.start_link(TH.Worker, batching_work_fun)
  end

  def process(server_pid, item) do
    GenServer.call(server_pid, {:process_item, item})
  end

  def simple_echo(items) do
    Map.new(items, &{&1, &1})
  end

  ## GenServer Callbacks

  def init(batching_work_fun) do
    {:ok, %TH.Worker{func: batching_work_fun}}
  end

  def handle_call({:process_item, item}, ref, %{working: true} = state) do
    {:ok, updated_batch} = TH.Batch.add_data(state.batch, ref, item)
    {:noreply, %{state | batch: updated_batch}}
  end

  def handle_call({:process_item, item}, ref, %{func: func} = state) do
    process_batch(TH.Batch.new(ref, item), func)
    {:noreply, %{state | working: true}}
  end

  def handle_cast(:batch_processed, %{batch: batch} = state) when empty?(batch) do
    {:noreply, %{state | working: false}}
  end

  def handle_cast(:batch_processed, %{batch: batch, func: func} = state) do
    process_batch(batch, func)
    {:noreply, %{state | batch: TH.Batch.new()}}
  end

  ## Private Functions

  defp process_batch(batch, func) do
    worker = self()

    spawn(fn ->
      try do
        batch
        |> TH.Batch.process(func)
        |> Enum.each(fn {ref, val} -> GenServer.reply(ref, val) end)
      after
        GenServer.cast(worker, :batch_processed)
      end
    end)
  end
end
