defmodule BinPacker.Objective do

  import BinPacker.Util, only: [sum_by: 2]

  alias BinPacker, as: BinPacker
  alias BinPacker.Ball

  @type init_args :: any
  @type state :: any
  @type proposition :: BinPacker.proposition()
  @type cost :: number() # non-neg

  @callback init(init_args) :: state
  @callback proposition_executed(BinPacker.t(), proposition, state) :: state
  @callback ball_added(BinPacker.t(), Ball.t, state) :: state
  @callback bin_added(BinPacker.t(), Bin.t, state) :: state
  @callback cost(BinPacker.t(), state) :: cost

  defstruct weights: Map.new(),
            states: Map.new()

  def initialize(bin_packer, objectives) do
    states =
      objectives
      |> Map.keys
      |> Enum.into(%{}, fn
        {module, args} = objective ->
          {objective, module.init(args)}

        module ->
          {module, module.init(nil)}
      end)

    %BinPacker{bin_packer |
      objectives: %__MODULE__{
        weights: objectives,
        states: states
      }
    }
  end

  def cost(%BinPacker{objectives: %__MODULE__{states: states, weights: weights}} = bin_packer) do
    sum_by(states, fn {objective, state} ->
      module = module(objective)

      objective_cost = module.cost(bin_packer, state)
      weight = Map.get(weights, objective)

      weight * objective_cost
    end)
  end

  #
  # Notifications
  #
  def ball_added(bin_packer, ball) do
    apply_to_all(bin_packer, :ball_added, [ball])
  end

  def bin_added(bin_packer, bin) do
    apply_to_all(bin_packer, :bin_added, [bin])
  end

  def proposition_executed(bin_packer, proposition) do
    apply_to_all(bin_packer, :proposition_executed, [proposition])
  end

  defp apply_to_all(%BinPacker{objectives: %__MODULE__{states: states} = objectives} = bin_packer, fun_name, args) do
    states =
      Enum.into(states, %{}, fn {objective, state} ->
        {objective, apply(module(objective), fun_name, [bin_packer | args] ++ [state])}
      end)

    %BinPacker{bin_packer | objectives: %__MODULE__{objectives | states: states}}
  end

  defp module(module) when is_atom(module), do: module
  defp module({module, _init_args}) when is_atom(module), do: module
end
