defmodule BinPacker.DummyConstraint do

  import BinPacker.Util, only: [stream_from_list: 1]

  alias BinPacker, as: BinPacker
  alias BinPacker.Assignments
  alias BinPacker.MoveProposition
  alias BinPacker.SwapProposition

  @behaviour BinPacker.Constraint

  @impl true
  def init([]), do: nil

  @impl true
  def ball_added(_bin_packer, _ball, state), do: state

  @impl true
  def bin_added(_bin_packer, _bin, state), do: state

  @impl true
  def proposition_executed(_bin_packer, _proposition, state), do: state

  # this suggests every bin, essentialy a "null" constraint
  @impl true
  def generate_propositions(bin_packer, MoveProposition, ball_id, _state) do
    current_bin_id = Assignments.bin_id(bin_packer, ball_id)

    bin_packer
    |> Assignments.bin_ids()
    |> Enum.filter(fn bin_id -> bin_id != current_bin_id end)
    |> Enum.map(&MoveProposition.new(bin_packer, ball_id, &1))
    |> stream_from_list()
  end

  def generate_propositions(bin_packer, SwapProposition, ball_id, _state) do
    bin_packer
    |> Assignments.ball_ids()
    |> Enum.filter(fn other_ball_id ->
      bin_id = Assignments.bin_id(bin_packer, ball_id)
      other_bin_id = Assignments.bin_id(bin_packer, other_ball_id)

      ball_id != other_ball_id && bin_id != other_bin_id
    end)
    |> Enum.map(&SwapProposition.new(bin_packer, ball_id, &1))
    |> stream_from_list()
  end

  @impl true
  def propose_new_placements(%BinPacker{assignments: %Assignments{bin_id_to_ball_ids: bin_id_to_ball_ids}}, _ball, _state) do
    bin_id_to_ball_ids
    |> Enum.sort_by(fn {_bin_id, ball_ids} ->
      Enum.count(ball_ids)
    end)
    |> Enum.map(fn {bin_id, _ball_ids} -> bin_id end)
    |> stream_from_list()
  end

  @impl true
  def valid_new_placement?(%BinPacker{}, _ball, _bin_id, _state), do: true

  @impl true
  def valid_proposition?(%BinPacker{}, _proposition, _state), do: true
end
