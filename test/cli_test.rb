require "test_helper"
require "knox_train/cli"

class CLITest < Minitest::Test
  def test_notify_if_enabled_with_nil_registry
    # When registry.global is nil, notifications should still be sent (default true)
    notifications_sent = []

    cli = KnoxTrain::CLI.new
    cli.define_singleton_method(:notify!) do |msg, opts = {}|
      notifications_sent << { message: msg, opts: opts }
    end

    registry = Minitest::Mock.new
    registry.expect(:global, nil)

    KnoxTrain.stub(:registry, registry) do
      cli.send(:notify_if_enabled, "test message")
    end

    assert_equal 1, notifications_sent.length
    assert_equal "test message", notifications_sent[0][:message]
  end

  def test_notify_if_enabled_with_notifications_true
    # When notifications is true, notifications should be sent
    notifications_sent = []

    cli = KnoxTrain::CLI.new
    cli.define_singleton_method(:notify!) do |msg, opts = {}|
      notifications_sent << { message: msg, opts: opts }
    end

    global_cfg = Minitest::Mock.new
    global_cfg.expect(:nil?, false)
    global_cfg.expect(:notifications, true)

    registry = Minitest::Mock.new
    registry.expect(:global, global_cfg)

    KnoxTrain.stub(:registry, registry) do
      cli.send(:notify_if_enabled, "test message")
    end

    assert_equal 1, notifications_sent.length
    assert_equal "test message", notifications_sent[0][:message]
  end

  def test_notify_if_enabled_with_notifications_false
    # When notifications is false, notifications should not be sent
    notifications_sent = []

    cli = KnoxTrain::CLI.new
    cli.define_singleton_method(:notify!) do |msg, opts = {}|
      notifications_sent << { message: msg, opts: opts }
    end

    global_cfg = Minitest::Mock.new
    global_cfg.expect(:nil?, false)
    global_cfg.expect(:notifications, false)

    registry = Minitest::Mock.new
    registry.expect(:global, global_cfg)

    KnoxTrain.stub(:registry, registry) do
      cli.send(:notify_if_enabled, "test message")
    end

    assert_equal 0, notifications_sent.length
  end

  def test_notify_if_enabled_passes_opts_to_notify
    # Verify that options are passed through to notify!
    notifications_sent = []

    cli = KnoxTrain::CLI.new
    cli.define_singleton_method(:notify!) do |msg, opts = {}|
      notifications_sent << { message: msg, opts: opts }
    end

    global_cfg = Minitest::Mock.new
    global_cfg.expect(:nil?, false)
    global_cfg.expect(:notifications, true)

    registry = Minitest::Mock.new
    registry.expect(:global, global_cfg)

    KnoxTrain.stub(:registry, registry) do
      cli.send(:notify_if_enabled, "test message", { activate: true })
    end

    assert_equal 1, notifications_sent.length
    assert_equal "test message", notifications_sent[0][:message]
    assert_equal({ activate: true }, notifications_sent[0][:opts])
  end
end
