defmodule ThunderingHerd.WorkerTest do
  use ExUnit.Case, async: true
  alias ThunderingHerd, as: TH
  doctest TH.Worker

  test "it can be started as a link" do
    assert {:ok, pid} = TH.Worker.start_link()
    assert Process.alive?(pid)
  end

  test "it can process something" do
    assert {:ok, pid} =
             TH.Worker.start_link(fn items ->
               Map.new(items, &{&1, &1 * 2})
             end)

    assert 4 == TH.Worker.process(pid, 2)
  end

  test "it will batch up items" do
    assert {:ok, pid} =
             TH.Worker.start_link(fn items ->
               Process.sleep(5)
               len = length(items)
               Map.new(items, &{&1, &1 * len})
             end)

    # This one should pass through by itself
    spawn(fn -> TH.Worker.process(pid, 1) end)

    # These two should pile up in a batch
    spawn(fn -> TH.Worker.process(pid, 2) end)
    spawn(fn -> TH.Worker.process(pid, 3) end)

    # Sleeping a little so all of the spawns have made it through
    Process.sleep(1)

    # At this point one item should be processing and two
    # in the batch, adding this one will increase the batch
    # size to 3, so the value should be 3 back since it multiplies
    # the value given by the number of items from the batch
    assert 3 == TH.Worker.process(pid, 1)
  end

  test "you can set a maximum batch size" do
    processor = fn items ->
      Process.sleep(5)
      Map.new(items, &{&1, items})
    end

    {:ok, pid} = TH.Worker.start_link(processor, batch_capacity: 2)

    # This one should pass through by itself
    spawn(fn -> TH.Worker.process(pid, 1) end)

    # These five should pile up in separate batches
    Enum.each(2..6, &spawn(fn -> TH.Worker.process(pid, &1) end))

    # Sleeping a little so all of the spawns have made it through
    Process.sleep(1)
    items = TH.Worker.process(pid, 1)

    assert length(items) == 2
    assert 1 in items
    assert 6 in items
  end

  test "you can specify a maximum concurrency" do
    processor = fn items ->
      Process.sleep(5)
      Map.new(items, &{&1, items})
    end

    {:ok, pid} = TH.Worker.start_link(processor, max_concurrency: 3)
    test = self()

    Enum.each(
      1..7,
      &spawn(fn ->
        send(test, {&1, TH.Worker.process(pid, &1)})
      end)
    )

    assert_receive {1, [1]}
    assert_receive {2, [2]}
    assert_receive {3, [3]}

    assert_receive {4, [4, 5, 6, 7]}
  end
end
