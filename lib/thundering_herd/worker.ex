defmodule ThunderingHerd.Worker do
  use GenServer
  alias ThunderingHerd, as: TH

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
    updated_batch = TH.Batch.add_data(state.batch, ref, item)
    {:noreply, %{state | batch: updated_batch}}
  end

  def handle_call({:process_item, item}, ref, %{func: func} = state) do
    process_batch(TH.Batch.new(ref, item), func)
    {:noreply, %{state | working: true}}
  end

  ## Private Functions

  def process_batch(batch, func) do
    worker = self()

    Task.async(fn ->
      batch
      |> TH.Batch.process(func)
      |> Enum.each(fn {ref, val} -> GenServer.reply(ref, val) end)

      GenServer.cast(worker, :batch_processed)
    end)
  end
end
