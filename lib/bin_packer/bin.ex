defprotocol BinPacker.Bin do
  def id(bin)
  def attribute(bin, name)
end
