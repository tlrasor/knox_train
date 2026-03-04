require "test_helper"

class CommandsTest < Minitest::Test
  def test_instantiation
    cmd = KnoxTrain::Commands.new(printer: :null)
    assert_instance_of KnoxTrain::Commands, cmd
  end

  def test_instantiation_default_printer
    cmd = KnoxTrain::Commands.new
    assert_instance_of KnoxTrain::Commands, cmd
  end
end
