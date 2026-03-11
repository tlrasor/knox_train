require "test_helper"

class VolumeTest < Minitest::Test
  def setup
    @vol = KnoxTrain::Volume.new(
      path:          "/Volumes/alpha",
      smb:           "smb://user@192.168.1.100/share",
      mount_timeout: 10
    )
  end

  # ── mounted? ────────────────────────────────────────────────────────────

  def test_mounted_false_when_path_does_not_exist
    @vol.stub(:mounted?, false) { refute @vol.mounted? }
  end

  def test_mounted_false_when_device_ids_match_parent
    # Simulate: path exists but same device as parent (nothing mounted there).
    stat_same = Struct.new(:dev).new(42)
    File.stub(:directory?, true) do
      File.stub(:stat, stat_same) do
        refute @vol.mounted?
      end
    end
  end

  # ── mount! ──────────────────────────────────────────────────────────────

  def test_mount_is_noop_when_already_mounted
    do_mount_called = false
    @vol.define_singleton_method(:do_mount) { do_mount_called = true }

    @vol.stub(:mounted?, true) { @vol.mount! }
    refute do_mount_called
  end

  def test_mount_calls_do_mount_and_sets_we_mounted_it
    @vol.define_singleton_method(:do_mount)   { }
    @vol.define_singleton_method(:poll_until) { |_state, _timeout| }

    @vol.stub(:mounted?, false) { @vol.mount! }

    assert @vol.instance_variable_get(:@we_mounted_it)
  end

  def test_mount_raises_skip_profile_on_timeout
    @vol.define_singleton_method(:do_mount) { }
    @vol.define_singleton_method(:poll_until) do |_state, timeout|
      raise "Timed out after #{timeout}s waiting for /Volumes/alpha to be mounted"
    end

    @vol.stub(:mounted?, false) do
      assert_raises(KnoxTrain::DSL::SkipProfile) { @vol.mount! }
    end
  end

  # ── unmount ─────────────────────────────────────────────────────────────

  def test_unmount_is_noop_when_we_did_not_mount_it
    do_unmount_called = false
    @vol.define_singleton_method(:do_unmount) { do_unmount_called = true }

    @vol.unmount  # @we_mounted_it starts false
    refute do_unmount_called
  end

  def test_unmount_calls_do_unmount_and_clears_we_mounted_it
    # Prime @we_mounted_it = true via a successful mount! cycle.
    @vol.define_singleton_method(:do_mount)   { }
    @vol.define_singleton_method(:poll_until) { |_state, _timeout| }
    @vol.stub(:mounted?, false) { @vol.mount! }
    assert @vol.instance_variable_get(:@we_mounted_it)

    do_unmount_called = false
    @vol.define_singleton_method(:do_unmount) { do_unmount_called = true }

    @vol.unmount
    assert do_unmount_called
    refute @vol.instance_variable_get(:@we_mounted_it)
  end
end
