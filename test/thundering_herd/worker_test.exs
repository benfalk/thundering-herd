defmodule ThunderingHerd.WorkerTest do
  use ExUnit.Case
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
end
