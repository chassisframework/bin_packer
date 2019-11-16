defmodule BinPacker.Neighbourhood do

  alias BinPacker, as: BinPacker
  alias BinPacker.Objective
  alias BinPacker.Proposition
  alias BinPacker.Constraint

  @default_max_runs 10

  def initialize(%BinPacker{} = bin_packer, neighbourhoods) do
    neighbourhoods =
      Enum.map(neighbourhoods, fn {module, args} = neighbourhood ->
        {neighbourhood, module.init(args)}
      end)

    %BinPacker{bin_packer | neighbourhoods: neighbourhoods}
  end

  def search(%BinPacker{neighbourhoods: neighbourhoods} = bin_packer, opts) do
    max_runs = Keyword.get(opts, :max_runs, @default_max_runs)

    Enum.reduce_while(0..max_runs, bin_packer, fn _i, bin_packer ->
      new_bin_packer =
        Enum.reduce(neighbourhoods, bin_packer, fn {{module, _init_args}, state}, bin_packer ->
          search_neighbourhood(bin_packer, module, state)
        end)

      if Objective.cost(new_bin_packer) < Objective.cost(bin_packer) do
        {:cont, new_bin_packer}
      else
        {:halt, bin_packer}
      end
    end)
  end

  defp search_neighbourhood(bin_packer, neighbourhood, state) do
    current_cost = BinPacker.cost(bin_packer)

    bin_packer
    |> neighbourhood.generate_propositions(state)
    |> Enum.map(fn proposition ->
      cost =
        bin_packer
        |> execute_proposition(proposition)
        |> Objective.cost()

      {cost, proposition}
    end)
    |> Enum.filter(fn {cost, _} -> cost < current_cost end)
    |> Enum.sort_by(fn {cost, _proposition} -> cost end)
    |> Enum.map(fn {_cost, proposition} -> proposition end)
    |> case do
         [] ->
           bin_packer

         propositions ->
           Enum.reduce(propositions, {bin_packer, current_cost}, fn proposition, {bin_packer, cost} ->
             # propositions can become invalidated by other previously executed propositions
             # e.g. a process has since been moved from the machine that the proposition expects it to be on
             if Proposition.valid?(proposition, bin_packer) && Constraint.valid_proposition?(bin_packer, proposition) do
               new_bin_packer = execute_proposition(bin_packer, proposition)
               new_cost = Objective.cost(new_bin_packer)

               if new_cost < cost do
                 {new_bin_packer, new_cost}
               else
                 {bin_packer, cost}
               end
             else
               {bin_packer, cost}
             end
           end)
           |> elem(0)
           |> search_neighbourhood(neighbourhood, state)
       end
  end

  defp execute_proposition(bin_packer, proposition) do
    proposition
    |> Proposition.execute(bin_packer)
    |> Objective.proposition_executed(proposition)
    |> Constraint.proposition_executed(proposition)
  end
end
