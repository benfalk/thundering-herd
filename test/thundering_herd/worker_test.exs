defmodule ThunderingHerd.WorkerTest do
  use ExUnit.Case
  alias ThunderingHerd, as: TH
  doctest TH.Worker

  test "it can be started as a link" do
    assert {:ok, pid} = TH.Worker.start_link()
    assert Process.alive?(pid)
  end

  test "it can process a batch" do
    {:ok, _, batch} = TH.Batch.new() |> TH.Batch.add_data(:yo_dawg)
    {:ok, _, batch} = TH.Batch.add_data(batch, :yo_dawg)

    assert {:ok, worker} = TH.Worker.start_link()
    assert {:ok, processed} = TH.Worker.process(worker, batch)
    IO.inspect(processed)
  end
end
