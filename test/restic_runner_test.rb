require "test_helper"
require "minitest/mock"

class ResticRunnerTest < Minitest::Test

  def make_backend(opts = {})
    KnoxTrain::Backend.new(
      type:        opts.fetch(:type, :b2),
      repo:        opts.fetch(:repo, "b2:bucket:test"),
      password:    opts.fetch(:password, -> { "testpass" }),
      retention:   opts.fetch(:retention, { daily: 7, weekly: 4 }),
      run_befores: opts.fetch(:run_befores, []),
      run_afters:  opts.fetch(:run_afters, []),
      env_credentials: opts.fetch(:env_credentials, {})
    )
  end

  def make_profile(opts = {})
    KnoxTrain::Profile.new(
      name:          opts.fetch(:name, :test),
      sources:       opts.fetch(:sources, ["/tmp"]),
      exclude_files: opts.fetch(:exclude_files, []),
      tags:          opts.fetch(:tags, ["test"]),
      host:          opts.fetch(:host, false),
      backends:      []
    )
  end

  # Builds a fake commands object that appends each exec'd command string to `executed`.
  def fake_commands_capturing(executed)
    obj = Object.new
    obj.define_singleton_method(:exec) { |cmd, **_opts| executed << cmd }
    obj
  end

  def capture_commands(profile, backend, **runner_opts)
    executed = []
    KnoxTrain::Restic::Runner.new(profile, backend, **runner_opts,
                                  commands: fake_commands_capturing(executed)).run
    executed
  end

  # ── Command building ─────────────────────────────────────────────────────

  def test_backup_command_includes_repo_and_source
    cmds = capture_commands(make_profile, make_backend)
    assert_equal 1, cmds.length
    assert_match(/restic/, cmds.first)
    assert_match(/-r\s+b2:bucket:test/, cmds.first)
    assert_match(%r{/tmp}, cmds.first)  # /tmp or /private/tmp on macOS — both match
  end

  def test_backup_command_includes_tags
    profile = make_profile(tags: ["docs", "important"])
    cmds = capture_commands(profile, make_backend)
    assert_match(/--tag docs/, cmds.first)
    assert_match(/--tag important/, cmds.first)
  end

  def test_backup_command_includes_exclude_file
    profile = make_profile(exclude_files: ["/tmp/excludes.txt"])
    cmds = capture_commands(profile, make_backend)
    assert_match(/--exclude-file/, cmds.first)
  end

  def test_backup_command_includes_standard_flags
    cmds = capture_commands(make_profile, make_backend)
    assert_match(/--exclude-caches/, cmds.first)
    assert_match(/--one-file-system/, cmds.first)
    assert_match(/--host/, cmds.first)
  end

  def test_forget_command_emitted_when_prune_and_retention
    cmds = capture_commands(make_profile, make_backend, prune: true)
    assert_equal 2, cmds.length
    assert_match(/forget/, cmds.last)
    assert_match(/--keep-daily 7/, cmds.last)
    assert_match(/--keep-weekly 4/, cmds.last)
  end

  def test_forget_not_emitted_when_prune_false
    cmds = capture_commands(make_profile, make_backend, prune: false)
    assert_equal 1, cmds.length
  end

  def test_forget_not_emitted_when_no_retention
    backend = make_backend(retention: nil)
    cmds = capture_commands(make_profile, backend, prune: true)
    assert_equal 1, cmds.length
  end

  # ── Env var management ───────────────────────────────────────────────────

  def test_restic_password_set_during_run
    password_seen = nil
    obj = Object.new
    obj.define_singleton_method(:exec) { |_cmd, **_opts| password_seen = ENV["RESTIC_PASSWORD"] }
    KnoxTrain::Restic::Runner.new(make_profile, make_backend, commands: obj).run
    assert_equal "testpass", password_seen
  end

  def test_restic_password_restored_after_run
    original = ENV["RESTIC_PASSWORD"]
    ENV.delete("RESTIC_PASSWORD")
    obj = Object.new
    obj.define_singleton_method(:exec) { |_cmd, **_opts| }
    KnoxTrain::Restic::Runner.new(make_profile, make_backend, commands: obj).run
    assert_nil ENV["RESTIC_PASSWORD"]
  ensure
    original.nil? ? ENV.delete("RESTIC_PASSWORD") : ENV["RESTIC_PASSWORD"] = original
  end

  def test_restic_password_restored_even_on_command_failure
    # Verifies the with_env ensure branch executes on failure.
    original = ENV["RESTIC_PASSWORD"]
    ENV.delete("RESTIC_PASSWORD")
    obj = Object.new
    obj.define_singleton_method(:exec) { |_cmd, **_opts| raise StandardError, "restic failed" }
    assert_raises(StandardError) do
      KnoxTrain::Restic::Runner.new(make_profile, make_backend, commands: obj).run
    end
    assert_nil ENV["RESTIC_PASSWORD"]
  ensure
    original.nil? ? ENV.delete("RESTIC_PASSWORD") : ENV["RESTIC_PASSWORD"] = original
  end

  def test_env_credentials_set_during_run
    key_seen = nil
    backend = make_backend(env_credentials: { "AWS_ACCESS_KEY_ID" => -> { "mykey" } })
    obj = Object.new
    obj.define_singleton_method(:exec) { |_cmd, **_opts| key_seen = ENV["AWS_ACCESS_KEY_ID"] }
    KnoxTrain::Restic::Runner.new(make_profile, backend, commands: obj).run
    assert_equal "mykey", key_seen
  end

  def test_env_credentials_restored_after_run
    ENV.delete("AWS_ACCESS_KEY_ID")
    backend = make_backend(env_credentials: { "AWS_ACCESS_KEY_ID" => -> { "mykey" } })
    obj = Object.new
    obj.define_singleton_method(:exec) { |_cmd, **_opts| }
    KnoxTrain::Restic::Runner.new(make_profile, backend, commands: obj).run
    assert_nil ENV["AWS_ACCESS_KEY_ID"]
  ensure
    ENV.delete("AWS_ACCESS_KEY_ID")
  end

  # ── Hooks ────────────────────────────────────────────────────────────────

  def test_before_and_after_hooks_called
    before_called = false
    after_called  = false
    backend = make_backend(
      run_befores: [-> { before_called = true }],
      run_afters:  [-> { after_called = true }]
    )
    obj = Object.new
    obj.define_singleton_method(:exec) { |_cmd, **_opts| }
    KnoxTrain::Restic::Runner.new(make_profile, backend, commands: obj).run
    assert before_called
    assert after_called
  end

  def test_after_hooks_run_even_on_command_failure
    after_called = false
    backend = make_backend(run_afters: [-> { after_called = true }])
    obj = Object.new
    obj.define_singleton_method(:exec) { |_cmd, **_opts| raise StandardError, "restic failed" }
    assert_raises(StandardError) do
      KnoxTrain::Restic::Runner.new(make_profile, backend, commands: obj).run
    end
    assert after_called
  end

  # ── SkipProfile ──────────────────────────────────────────────────────────

  def test_skip_profile_raised_from_source_block_propagates
    # SkipProfile raised in resolve_sources propagates before hooks start.
    # run_after hooks do NOT run (ensure block is only entered after hooks begin).
    skip_source = -> { raise KnoxTrain::DSL::SkipProfile, "not mounted" }
    obj = Object.new
    obj.define_singleton_method(:exec) { |_cmd, **_opts| raise "should not be called" }
    assert_raises(KnoxTrain::DSL::SkipProfile) do
      KnoxTrain::Restic::Runner.new(
        make_profile(sources: [skip_source]),
        make_backend,
        commands: obj
      ).run
    end
  end
end
