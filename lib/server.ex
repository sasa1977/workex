defmodule Workex.Server do
  @moduledoc """
    A gen_server based process which can be used to manipulate multiple workers and send
    them messages. See readme for detailed description.
  """

  use ExActor.Tolerant

  alias Workex.Worker.Queue

  defstart start(worker_args)
  defstart start_link(worker_args) do
    initial_state(Queue.new(worker_args))
  end

  defcast push(message), state: queue do
    queue
    |> Queue.push(message)
    |> new_state
  end

  defhandleinfo {:workex, :worker_available}, state: queue do
    queue
    |> Queue.worker_available(true)
    |> new_state
  end

  defhandleinfo _, do: noreply
end