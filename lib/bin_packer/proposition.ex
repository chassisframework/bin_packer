defprotocol BinPacker.Proposition do
  def valid?(proposition, bin_packer)
  def execute(proposition, bin_packer)
end
