defmodule ThunderingHerd.Queue do
  alias ThunderingHerd, as: TH
  @default_batch_capacity 30

  @typedoc """
  A four-pair tuple with the following details:

    1. number of batches that are enqueued
    2. maximum size for every batch
    3. queue of filled up batches awaiting process
    4. most recent batch being filled up

  This is designed as a tuple instead of a struct mostly
  so it can be used with a guard and the slight performance
  gain with direct access instead of hash lookups.
  """
  @type t :: {
          non_neg_integer(),
          pos_integer(),
          :queue.queue(TH.Batch.t()),
          TH.Batch.t()
        }

  defguard empty?(queue) when elem(queue, 0) == 0 and map_size(elem(queue, 3)) == 0

  @spec new() :: t()
  @spec new(pos_integer()) :: t()
  def new(batch_capacity \\ @default_batch_capacity) do
    {0, batch_capacity, :queue.new(), TH.Batch.new()}
  end

  @spec add(t(), GenServer.from(), any()) :: {:ok, t()}
  def add({enqueued, max_batch, queue, batch}, ref, item) do
    {:ok, batch} = TH.Batch.add_data(batch, ref, item)

    {:ok,
     if TH.Batch.size(batch) == max_batch do
       {enqueued + 1, max_batch, :queue.in(batch, queue), TH.Batch.new()}
     else
       {enqueued, max_batch, queue, batch}
     end}
  end

  @spec total_enqueued(t()) :: non_neg_integer()
  def total_enqueued({enqueued, max_batch, _, batch}) do
    enqueued * max_batch + TH.Batch.size(batch)
  end

  @spec enqueued_batches(t()) :: non_neg_integer()
  def enqueued_batches({amount, _, _, _}), do: amount

  @spec next_batch(t()) :: {:ok, TH.Batch.t(), t()}
  def next_batch({0, max_batch, queue, batch}) do
    {:ok, batch, {0, max_batch, queue, TH.Batch.new()}}
  end

  def next_batch({enqueued, max_batch, queue, batch}) do
    {{:value, next_batch}, new_queue} = :queue.out(queue)
    {:ok, next_batch, {enqueued - 1, max_batch, new_queue, batch}}
  end
end
