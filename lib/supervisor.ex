defmodule Workex.Worker.Supervisor do
  use Supervisor.Behaviour

  def init(args) do
    tree = [worker(Workex.Worker, [], args)]
    supervise(tree, strategy: :simple_one_for_one)
  end
end