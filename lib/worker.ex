defmodule Workex.Worker do
  use ExActor.Tolerant

  defstruct [:id, :queue_pid, :job, :state]

  defstart start(args)
  defstart start_link(args) do
    %__MODULE__{
      id: args[:id],
      queue_pid: args[:queue_pid],
      job: args[:job],
      state: args[:state]
    }
    |> notify_parent
    |> initial_state
  end

  defp notify_parent(%__MODULE__{queue_pid: queue_pid, id: id} = worker) do
    send(queue_pid, {:workex, {:worker_created, id, self}})
    worker
  end


  defcast process(messages), state: worker do
    worker
    |> exec_job(messages)
    |> new_state
  end

  def exec_job(
    %__MODULE__{id: id, queue_pid: queue_pid, job: job, state: state} = worker,
    messages
  ) do
      new_state = job.(messages, state)
      send(queue_pid, {:workex, {:worker_available, id}})
      %__MODULE__{worker | state: new_state}
  end
end