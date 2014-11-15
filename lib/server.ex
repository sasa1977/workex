defmodule Workex.Server do
  @moduledoc """
    A gen_server based process which can be used to manipulate multiple workers and send
    them messages. See readme for detailed description.
  """

  use ExActor.Tolerant

  defstart start(workex_args)
  defstart start_link(workex_args) do
    initial_state(Workex.new(workex_args))
  end

  defcast push(worker_id, message), state: workex do
    new_state(Workex.push(workex, worker_id, message))
  end
  
  defhandleinfo {:workex, msg}, state: workex do
    workex
    |> Workex.handle_message(msg)
    |> new_state
  end

  defhandleinfo _, do: noreply
end