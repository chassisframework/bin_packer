defmodule BinPacker.SwapProposition do
  @moduledoc false

  alias BinPacker.Assignments
  alias BinPacker.Proposition

  defstruct [
    :ball_id,
    :other_ball_id,
    :bin_id,
    :other_bin_id
  ]

  def new(bin_packer, ball_id, other_ball_id) do
    bin_id = Assignments.bin_id(bin_packer, ball_id)
    other_bin_id = Assignments.bin_id(bin_packer, other_ball_id)

    if ball_id == other_ball_id do
      raise "ball_id == other_ball_id, this is a bug!"
    end

    if bin_id == other_bin_id do
      raise "bin_id == other_bin_id, this is a bug!"
    end

    %__MODULE__{
      ball_id: ball_id,
      other_ball_id: other_ball_id,
      bin_id: bin_id,
      other_bin_id: other_bin_id
    }
  end

  defimpl Proposition do
    def valid?(
      %@for{
        ball_id: ball_id,
        other_ball_id: other_ball_id,
        bin_id: bin_id,
        other_bin_id: other_bin_id
      },
      bin_packer
    ) do
      ball_id != other_ball_id
      && bin_id != other_bin_id
      && bin_id == Assignments.bin_id(bin_packer, ball_id)
      && other_bin_id == Assignments.bin_id(bin_packer, other_ball_id)
    end

    def execute(
      %@for{
        ball_id: ball_id,
        other_ball_id: other_ball_id,
        bin_id: bin_id,
        other_bin_id: other_bin_id
      },
      bin_packer
    ) do
      bin_packer
      |> Assignments.move_ball_id(ball_id, bin_id, other_bin_id)
      |> Assignments.move_ball_id(other_ball_id, other_bin_id, bin_id)
    end
  end
end
