defmodule ThunderingHerd.Worker do
  use GenServer
  alias ThunderingHerd, as: TH
  import TH.Queue, only: [empty?: 1]
  @default_batch_capacity 30

  defstruct working: false,
            queue: TH.Queue.new(),
            func: nil

  def start_link(batching_work_fun \\ &TH.Worker.simple_echo/1, opts \\ []) do
    GenServer.start_link(TH.Worker, [func: batching_work_fun] ++ opts)
  end

  def process(server_pid, item) do
    GenServer.call(server_pid, {:process_item, item})
  end

  def simple_echo(items) do
    Map.new(items, &{&1, &1})
  end

  ## GenServer Callbacks

  def init(args) do
    {:ok,
     %TH.Worker{
       func: Keyword.fetch!(args, :func),
       queue: TH.Queue.new(Keyword.get(args, :batch_capacity, @default_batch_capacity))
     }}
  end

  def handle_call({:process_item, item}, ref, %{working: true} = state) do
    {:ok, updated_queue} = TH.Queue.add(state.queue, ref, item)
    {:noreply, %{state | queue: updated_queue}}
  end

  def handle_call({:process_item, item}, ref, %{func: func} = state) do
    process_batch(TH.Batch.new(ref, item), func)
    {:noreply, %{state | working: true}}
  end

  def handle_cast(:batch_processed, %{queue: queue} = state) when empty?(queue) do
    {:noreply, %{state | working: false}}
  end

  def handle_cast(:batch_processed, %{queue: queue, func: func} = state) do
    {:ok, batch, updated_queue} = TH.Queue.next_batch(queue)
    process_batch(batch, func)
    {:noreply, %{state | queue: updated_queue}}
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
