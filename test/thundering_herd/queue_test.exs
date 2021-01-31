defmodule ThunderingHerd.QueueTest do
  use ExUnit.Case, async: true
  alias ThunderingHerd, as: TH
  require TH.Queue
  require TH.Batch

  test "can make a new empty queue" do
    queue = TH.Queue.new()
    assert TH.Queue.empty?(queue)
  end

  test "can add an item to the queue" do
    queue = TH.Queue.new()
    {:ok, updated} = TH.Queue.add(queue, make_ref(), :yo_dawg)
    assert 1 == TH.Queue.total_enqueued(updated)
  end

  test "you can queue up multiple batches" do
    queue = TH.Queue.new(2)

    updated =
      Enum.reduce(1..11, queue, fn i, q ->
        {:ok, next} = TH.Queue.add(q, make_ref(), i)
        next
      end)

    assert TH.Queue.enqueued_batches(updated) == 5
    assert TH.Queue.total_enqueued(updated) == 11
  end

  test "fetching batches from the queue" do
    queue = TH.Queue.new(2)

    updated =
      Enum.reduce(1..3, queue, fn i, q ->
        {:ok, next} = TH.Queue.add(q, make_ref(), i)
        next
      end)

    {:ok, first_batch, updated} = TH.Queue.next_batch(updated)

    assert TH.Batch.size(first_batch) == 2
    assert 1 in TH.Batch.items(first_batch)
    assert 2 in TH.Batch.items(first_batch)
    assert TH.Queue.enqueued_batches(updated) == 0
    assert TH.Queue.total_enqueued(updated) == 1

    {:ok, last_batch, updated} = TH.Queue.next_batch(updated)
    assert [3] == TH.Batch.items(last_batch)
    assert TH.Queue.enqueued_batches(updated) == 0
    assert TH.Queue.total_enqueued(updated) == 0
  end
end
