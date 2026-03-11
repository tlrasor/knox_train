# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'

class SchedulerLaunchdTest < Minitest::Test
  def make_agent(opts = {})
    KnoxTrain::Scheduler::Launchd.new(
      config_path: opts.fetch(:config_path, '/path/to/knox_train.rb'),
      hour: opts.fetch(:hour, 2),
      minute: opts.fetch(:minute, 0)
    )
  end

  def stub_launchctl(agent)
    calls = []
    agent.define_singleton_method(:launchctl) do |sub, path|
      calls << [sub, path]
      true
    end
    calls
  end

  def stub_log_dir(agent)
    agent.define_singleton_method(:ensure_log_dir) { nil }
  end

  # ── plist path ─────────────────────────────────────────────────────────────

  def test_plist_path_includes_label
    assert_includes make_agent.plist_path, KnoxTrain::Scheduler::Launchd::LABEL
  end

  def test_plist_path_is_in_launch_agents
    assert_includes make_agent.plist_path, 'LaunchAgents'
  end

  def test_plist_path_ends_with_plist
    assert make_agent.plist_path.end_with?('.plist')
  end

  # ── plist content ───────────────────────────────────────────────────────────

  def test_install_writes_plist_with_label
    Dir.mktmpdir do |dir|
      agent = make_agent
      agent.define_singleton_method(:plist_path) { File.join(dir, 'test.plist') }
      stub_launchctl(agent)
      stub_log_dir(agent)
      agent.install
      assert_includes File.read(agent.plist_path), KnoxTrain::Scheduler::Launchd::LABEL
    end
  end

  def test_install_embeds_hour_and_minute
    Dir.mktmpdir do |dir|
      agent = make_agent(hour: 3, minute: 30)
      agent.define_singleton_method(:plist_path) { File.join(dir, 'test.plist') }
      stub_launchctl(agent)
      stub_log_dir(agent)
      agent.install
      content = File.read(agent.plist_path)
      assert_match(%r{<integer>3</integer>}, content)
      assert_match(%r{<integer>30</integer>}, content)
    end
  end

  def test_install_embeds_config_path
    Dir.mktmpdir do |dir|
      agent = make_agent(config_path: '/custom/path/knox_train.rb')
      agent.define_singleton_method(:plist_path) { File.join(dir, 'test.plist') }
      stub_launchctl(agent)
      stub_log_dir(agent)
      agent.install
      assert_includes File.read(agent.plist_path), '/custom/path/knox_train.rb'
    end
  end

  def test_install_includes_backup_all_arguments
    Dir.mktmpdir do |dir|
      agent = make_agent
      agent.define_singleton_method(:plist_path) { File.join(dir, 'test.plist') }
      stub_launchctl(agent)
      stub_log_dir(agent)
      agent.install
      content = File.read(agent.plist_path)
      assert_match(%r{<string>backup</string>}, content)
      assert_match(%r{<string>--all</string>}, content)
    end
  end

  # ── install / uninstall lifecycle ───────────────────────────────────────────

  def test_install_calls_launchctl_load
    Dir.mktmpdir do |dir|
      agent = make_agent
      agent.define_singleton_method(:plist_path) { File.join(dir, 'test.plist') }
      calls = stub_launchctl(agent)
      stub_log_dir(agent)
      agent.install
      assert_equal 'load', calls.last.first
    end
  end

  def test_install_unloads_first_if_plist_exists
    Dir.mktmpdir do |dir|
      plist = File.join(dir, 'test.plist')
      File.write(plist, '<plist/>')
      agent = make_agent
      agent.define_singleton_method(:plist_path) { plist }
      calls = stub_launchctl(agent)
      stub_log_dir(agent)
      agent.install
      assert_equal 'unload', calls.first.first
      assert_equal 'load',   calls.last.first
    end
  end

  def test_install_skips_unload_if_plist_absent
    Dir.mktmpdir do |dir|
      agent = make_agent
      agent.define_singleton_method(:plist_path) { File.join(dir, 'new.plist') }
      calls = stub_launchctl(agent)
      stub_log_dir(agent)
      agent.install
      assert_equal 1, calls.length
      assert_equal 'load', calls.first.first
    end
  end

  def test_uninstall_calls_launchctl_unload
    Dir.mktmpdir do |dir|
      plist = File.join(dir, 'test.plist')
      File.write(plist, '<plist/>')
      agent = make_agent
      agent.define_singleton_method(:plist_path) { plist }
      calls = stub_launchctl(agent)
      agent.uninstall
      assert_equal 'unload', calls.first.first
      refute File.exist?(plist)
    end
  end

  def test_uninstall_is_noop_when_not_installed
    agent = make_agent
    agent.define_singleton_method(:plist_path) { '/nonexistent/path/does-not-exist.plist' }
    calls = stub_launchctl(agent)
    agent.uninstall
    assert_empty calls
  end
end
