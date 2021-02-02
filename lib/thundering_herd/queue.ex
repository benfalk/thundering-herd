defmodule ThunderingHerd.Queue do
  alias ThunderingHerd, as: TH
  require TH.Batch
  @default_batch_capacity 30

  defguard empty?(queue) when elem(queue, 0) == 0 and map_size(elem(queue, 3)) == 0

  def new(batch_capacity \\ @default_batch_capacity) do
    {0, batch_capacity, :queue.new(), TH.Batch.new()}
  end

  def add({enqueued, max_batch, queue, batch}, ref, item) do
    {:ok, batch} = TH.Batch.add_data(batch, ref, item)

    {:ok,
     if TH.Batch.size(batch) == max_batch do
       {enqueued + 1, max_batch, :queue.in(batch, queue), TH.Batch.new()}
     else
       {enqueued, max_batch, queue, batch}
     end}
  end

  def total_enqueued({enqueued, max_batch, _, batch}) do
    enqueued * max_batch + TH.Batch.size(batch)
  end

  def enqueued_batches({amount, _, _, _}), do: amount

  def next_batch({0, max_batch, queue, batch}) do
    {:ok, batch, {0, max_batch, queue, TH.Batch.new()}}
  end

  def next_batch({enqueued, max_batch, queue, batch}) do
    {{:value, next_batch}, new_queue} = :queue.out(queue)
    {:ok, next_batch, {enqueued - 1, max_batch, new_queue, batch}}
  end
end
