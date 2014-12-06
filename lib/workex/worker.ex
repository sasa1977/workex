defmodule Workex.Worker do
  use ExActor.Tolerant

  defstruct [:queue_pid, :job, :state]

  defstart start(args)
  defstart start_link(args) do
    %__MODULE__{
      queue_pid: args[:queue_pid],
      job: args[:job],
      state: args[:state]
    }
    |> initial_state
  end


  defcast process(messages), state: worker do
    worker
    |> exec_job(messages)
    |> new_state
  end

  def exec_job(
    %__MODULE__{queue_pid: queue_pid, job: job, state: state} = worker,
    messages
  ) do
      new_state = job.(messages, state)
      send(queue_pid, {:workex, :worker_available})
      %__MODULE__{worker | state: new_state}
  end
end