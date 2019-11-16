defmodule BinPacker.MoveNeighbourhood do
  @moduledoc false

  alias BinPacker.Assignments
  alias BinPacker.MoveProposition
  alias BinPacker.Constraint

  # @behaviour MachineAssignment.Neighborhood

  defmodule State do
    defstruct [
      :max_balls,
      :max_bins
    ]
  end

  def init(%{max_balls: max_balls, max_bins: max_bins}) do
    %State{max_balls: max_balls, max_bins: max_bins}
  end

  def generate_propositions(bin_packer, %State{max_balls: max_balls, max_bins: max_bins}) do
    bin_packer
    |> Assignments.ball_ids()
    |> Enum.take_random(max_balls)
    |> Enum.flat_map(fn ball_id ->
      Constraint.generate_propositions(bin_packer, MoveProposition, ball_id, max_bins)
    end)
  end
end
