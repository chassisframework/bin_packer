defmodule BinPacker.SwapNeighbourhood do
  @moduledoc false

  alias BinPacker.Assignments
  alias BinPacker.SwapProposition
  alias BinPacker.Constraint

  # @behaviour MachineAssignment.Neighborhood

  defmodule State do
    defstruct [
      :max_swaps
    ]
  end

  def init(%{max_swaps: max_swaps}) do
    %State{max_swaps: max_swaps}
  end

  def generate_propositions(bin_packer, %State{max_swaps: max_swaps}) do
    bin_packer
    |> Assignments.ball_ids()
    |> Enum.take_random(max_swaps)
    |> Enum.flat_map(fn ball_id ->
      Constraint.generate_propositions(bin_packer, SwapProposition, ball_id, max_swaps)
    end)
  end
end
