defmodule Workex.Worker do
  use ExActor
  
  defrecord State, [:id, :queue_pid, :job, :state] do
    defoverridable [new: 1]
    def new(data) do
      super(data) |> notify_parent
    end

    defp notify_parent(
      __MODULE__[queue_pid: queue_pid, id: id] = this
    ) do
      send(queue_pid, {:workex, {:worker_created, id, self}})
      this
    end

    def exec_job(messages, 
      __MODULE__[id: id, queue_pid: queue_pid, job: job, state: state] = this
    ) do
      new_state = job.(messages, state)
      send(queue_pid, {:workex, {:worker_available, id}})
      this.state(new_state)
    end
  end
  
  def init(args) do
    initial_state(State.new(args))
  end
  
  defcast process(messages), state: state do
    new_state(state.exec_job(messages))
  end
end