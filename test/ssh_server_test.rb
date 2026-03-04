require "test_helper"
require "minitest/mock"

class SshServerTest < Minitest::Test
  def setup
    @server = KnoxTrain::SshServer.new(
      host: "nas.local", user: "admin", mac: "00:11:22:33:44:55",
      ip: "192.168.1.100", wake_timeout: 10, shutdown_timeout: 10
    )
  end

  # ── online? ─────────────────────────────────────────────────────────────

  def test_online_delegates_to_reachable
    @server.stub(:reachable?, true)  { assert @server.online? }
    @server.stub(:reachable?, false) { refute @server.online? }
  end

  # ── wake ────────────────────────────────────────────────────────────────

  def test_wake_skips_wol_when_already_online
    @server.stub(:online?, true) do
      @server.wake  # returns early — Commands never called
    end
    # @we_woke_it stays false — subsequent shutdown is a no-op
    exec_called = false
    @server.stub(:exec, ->(_) { exec_called = true }) do
      @server.shutdown
    end
    refute exec_called
  end

  def test_wake_sends_wol_and_polls_when_offline
    wol_called = false
    fake_commands = Object.new
    # exec takes one positional arg here (no nice/ionice — SshServer WoL call is bare)
    fake_commands.define_singleton_method(:exec) { |_cmd| wol_called = true }

    # online? returns false so wake proceeds; poll_until is stubbed so it doesn't loop.
    @server.stub(:online?, false) do
      KnoxTrain::Commands.stub(:new, fake_commands) do
        @server.stub(:poll_until, nil) do
          @server.wake
        end
      end
    end
    assert wol_called
  end

  # ── shutdown ────────────────────────────────────────────────────────────

  def test_shutdown_skips_when_we_did_not_wake_it
    # Default @we_woke_it = false, so shutdown returns early without calling exec.
    exec_called = false
    @server.stub(:exec, ->(_) { exec_called = true }) do
      @server.shutdown
    end
    refute exec_called
  end

  def test_shutdown_runs_after_wake
    # Drive a full wake cycle to set @we_woke_it = true.
    fake_commands = Object.new
    fake_commands.define_singleton_method(:exec) { |_cmd| }

    @server.stub(:online?, false) do
      KnoxTrain::Commands.stub(:new, fake_commands) do
        @server.stub(:poll_until, nil) do
          @server.wake
        end
      end
    end

    # @we_woke_it is now true. Shutdown should call exec (SSH poweroff).
    exec_called = false
    @server.stub(:exec, ->(_) { exec_called = true }) do
      @server.stub(:poll_until, nil) do
        @server.shutdown
      end
    end
    assert exec_called
  end

  # ── exec ────────────────────────────────────────────────────────────────

  def test_exec_runs_ssh_command
    executed = nil
    fake_commands = Object.new
    # SshServer#exec calls Commands.new.exec(cmd) with no nice/ionice kwargs
    fake_commands.define_singleton_method(:exec) { |cmd| executed = cmd }

    KnoxTrain::Commands.stub(:new, fake_commands) do
      @server.exec("/sbin/poweroff")
    end
    assert_match(/ssh/, executed)
    assert_match(/poweroff/, executed)
    assert_match(/admin@192\.168\.1\.31/, executed)
  end
end
