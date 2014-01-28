defmodule Workex.Server do
  @moduledoc """
    A gen_server based process which can be used to manipulate multiple workers and send 
    them messages. See readme for detailed description.
  """

  use ExActor.Tolerant
  
  def init(workex_args) do
    initial_state(Workex.new(workex_args))
  end
  
  defcast push(worker_id, message), state: workex do
    new_state(Workex.push(worker_id, message, workex))
  end
  
  def handle_info({:workex, msg}, workex), do: new_state(Workex.handle_message(msg, workex))
  def handle_info(_, workex), do: new_state(workex)
end