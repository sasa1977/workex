defmodule Workex.Worker do
  use ExActor.Tolerant

  defstruct [:queue_pid, :callback, :state]

  defstart start(queue_pid, callback, arg)
  defstart start_link(queue_pid, callback, arg) do
    %__MODULE__{
      queue_pid: queue_pid,
      callback: callback,
      state: callback.init(arg)
    }
    |> initial_state
  end


  defcast process(messages), state: worker do
    worker
    |> exec_job(messages)
    |> new_state
  end

  def exec_job(
    %__MODULE__{queue_pid: queue_pid, callback: callback, state: state} = worker,
    messages
  ) do
      new_state = callback.handle(messages, state)
      send(queue_pid, {:workex, :worker_available})
      %__MODULE__{worker | state: new_state}
  end
end