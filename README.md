# Thundering Herd

Designed to alleviate pressure that can occur from a sudden influx of traffic
that puts a strain on a resource.  This is done by queueing up batches of
requests and allows you to more efficiently access such resources and return
the results to the intended requests.

## Example

Let's pretend you have a scenario where an update has gone for your application
and as a result; hundreds of thousands of requests are coming in from the
application to get user specific data after the update.  All of these requests
would normally be waiting around for a free database connection to use.

Instead of each one having it's own turn, we can batch up all of these requests
need for some specific data and make fewer optimized calls to the database:

### The Worker

```elixir
defmodule UserSettingsRepo do
  import Ecto.Query, only: [from: 2]
  alias ThunderingHerd.Worker

  def start_link do
    # the worker expects a function which receives a list of terms to
    # process for and return a map where the key is the original term
    # and it's value is the result of processing
    fetching_fun = fn ids ->
      from(u in User, select: {u.id, u.settings}, where: u.id in ^ids)
      |> Repo.all()
      |> Map.new()
    end

    # Batch capacity defines how many at most will be passed at once for
    # processing.  The batches are enqueued; so it's first in, first out.
    #
    # Max concurrency describes how many batches will be called concurrently
    # to be processed.  Presently, what this means in this example is the
    # first four requests that come in will each be given their own batch of
    # one.  While those four are fetching additional requests will queue up
    # in batches.
    Worker.start_link(
      fetching_fun,
      batch_capacity: 20,
      max_concurrency: 4,
      name: __MODULE__
    )
  end

  def fetch(id), do: Worker.process(__MODULE__, id)
end
```

### How it looks logically

```
                    +-------------------------------------------+
                    |                                           |
                    |    Many Separate Requests for Settings    |
                    |                                           |
                    ++-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-++
                     | ^ | ^ | ^ | ^ | ^ | ^ | ^ | ^ | ^ | ^ | ^
                     | | | | | | | | | | | | | | | | | | | | | |
                     v | v | v | v | v | v | v | v | v | v | v |
                    ++-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-++
                    |                                           |
                    |   Worker tags requester, batches up all   |
                    |   request terms and batch processes them  |
                    |                                           |
                    +--+---+---+----+----+----+---+----+--------+
                       |   ^   |    ^    |    ^   |    ^
                       |   |   |    |    |    |   |    |
                       v   |   v    |    v    |   v    |
                    +--+---+---+----+----+----+---+----+--------+
                    |                                           |
                    |   Repo making bulk requests for settings  |
                    |                                           |
                    +-------------------------------------------+
```

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `thundering_herd` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:thundering_herd, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/thundering_herd](https://hexdocs.pm/thundering_herd).

