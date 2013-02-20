defmodule Workex.Worker do
  use ExActor
  
  defrecord State, [:id, :queue_pid, :job, :state] do
    def exec_job(messages, this) do
      this.job.(messages, this.state) |> 
      this.handle_job_response
    end
    
    def handle_job_response(new_state, this), do: this.state(new_state).worker_available
    
    def worker_available(this) do
      this.queue_pid <- {:workex, {:worker_available, this.id}}
      this
    end

    def notify_parent(this) do
      this.queue_pid <- {:workex, {:worker_created, this.id, self}}
      this
    end
  end
  
  def init(args) do
    initial_state(State.new(args).notify_parent)
  end
  
  def handle_info({:workex, :worker_available}, state) do
    new_state(state.worker_available)
  end
  
  def handle_info({:workex, :new_data, messages}, state) do
    new_state(state.exec_job(messages))
  end
  
  def handle_info(_, state), do: new_state(state)
end