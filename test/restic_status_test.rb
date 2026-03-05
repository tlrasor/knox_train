require "test_helper"
require "minitest/mock"

class ResticStatusTest < Minitest::Test

  SNAPSHOTS_JSON = JSON.generate([
    { "time" => "2026-03-01T10:00:00Z", "hostname" => "host" },
    { "time" => "2026-03-04T12:30:00Z", "hostname" => "host" }
  ])
  STATS_JSON = JSON.generate({ "total_size" => 1_073_741_824, "total_file_count" => 5000 })
  RAW_JSON   = JSON.generate({ "total_size" => 536_870_912 })

  def make_backend(opts = {})
    KnoxTrain::Backend.new(
      type:            opts.fetch(:type, :b2),
      repo:            opts.fetch(:repo, "b2:bucket:test"),
      password:        opts.fetch(:password, -> { "testpass" }),
      retention:       opts.fetch(:retention, nil),
      run_befores:     opts.fetch(:run_befores, []),
      run_afters:      opts.fetch(:run_afters, []),
      env_credentials: opts.fetch(:env_credentials, {})
    )
  end

  def make_profile(opts = {})
    KnoxTrain::Profile.new(
      name:          opts.fetch(:name, :docs),
      sources:       opts.fetch(:sources, ["/tmp"]),
      exclude_files: opts.fetch(:exclude_files, []),
      tags:          opts.fetch(:tags, ["docs"]),
      host:          opts.fetch(:host, false),
      backends:      []
    )
  end

  # Returns an exec-able object that yields outputs[0], outputs[1], ... in order.
  # exec signature matches Commands#exec: one positional arg + keyword args.
  def fake_commands_sequence(*outputs)
    idx = 0
    obj = Object.new
    obj.define_singleton_method(:exec) do |_cmd, **_opts|
      result = Struct.new(:out).new(outputs[idx])
      idx += 1
      result
    end
    obj
  end

  # ── fetch ────────────────────────────────────────────────────────────────

  def test_fetch_returns_snapshot_data
    cmds = fake_commands_sequence(SNAPSHOTS_JSON, STATS_JSON, RAW_JSON)
    data = KnoxTrain::Restic::Status.new(make_profile, make_backend, commands: cmds).fetch
    assert_equal :docs,                  data.profile_name
    assert_equal :b2,                    data.backend_type
    assert_equal 2,                      data.snapshot_count
    assert_equal "2026-03-04T12:30:00Z", data.latest_time
    assert_equal 5000,                   data.file_count
    assert_equal 1_073_741_824,          data.restore_bytes
    assert_equal 536_870_912,            data.stored_bytes
  end

  def test_fetch_latest_is_max_time
    snaps = JSON.generate([
      { "time" => "2026-01-01T00:00:00Z" },
      { "time" => "2026-03-10T09:00:00Z" },
      { "time" => "2026-02-15T12:00:00Z" }
    ])
    cmds = fake_commands_sequence(snaps, STATS_JSON, RAW_JSON)
    data = KnoxTrain::Restic::Status.new(make_profile, make_backend, commands: cmds).fetch
    assert_equal "2026-03-10T09:00:00Z", data.latest_time
  end

  def test_fetch_empty_snapshots
    cmds = fake_commands_sequence("[]", STATS_JSON, RAW_JSON)
    data = KnoxTrain::Restic::Status.new(make_profile, make_backend, commands: cmds).fetch
    assert_equal 0, data.snapshot_count
    assert_nil data.latest_time
  end

  def test_fetch_handles_json_parse_error_gracefully
    # JSON::ParserError on all three calls — parse_json returns [] / {} defaults.
    cmds = fake_commands_sequence("not json", "also not json", "still not json")
    data = KnoxTrain::Restic::Status.new(make_profile, make_backend, commands: cmds).fetch
    assert_equal 0, data.snapshot_count
    assert_equal 0, data.file_count
    assert_equal 0, data.restore_bytes
    assert_equal 0, data.stored_bytes
  end

  def test_fetch_includes_repo_in_commands
    executed = []
    obj = Object.new
    # Returns "{}" for all — safe for both snapshots (length/any? work on Hash) and
    # stats/raw (Hash#[] returns nil, || 0 gives 0).
    obj.define_singleton_method(:exec) { |cmd, **_opts| executed << cmd; Struct.new(:out).new("{}") }
    KnoxTrain::Restic::Status.new(make_profile, make_backend, commands: obj).fetch
    assert executed.all? { |cmd| cmd.include?("b2:bucket:test") }
  end

  def test_fetch_uses_json_flags
    executed = []
    obj = Object.new
    obj.define_singleton_method(:exec) { |cmd, **_opts| executed << cmd; Struct.new(:out).new("{}") }
    KnoxTrain::Restic::Status.new(make_profile, make_backend, commands: obj).fetch
    assert executed.all? { |cmd| cmd.include?("--json") }
  end

  def test_fetch_includes_tags_in_commands
    executed = []
    obj = Object.new
    obj.define_singleton_method(:exec) { |cmd, **_opts| executed << cmd; Struct.new(:out).new("{}") }
    profile = make_profile(tags: ["photos", "archive"])
    KnoxTrain::Restic::Status.new(profile, make_backend, commands: obj).fetch
    assert_match(/--tag photos/,  executed.first)
    assert_match(/--tag archive/, executed.first)
  end

  def test_raw_stats_command_includes_mode_flag
    executed = []
    obj = Object.new
    obj.define_singleton_method(:exec) { |cmd, **_opts| executed << cmd; Struct.new(:out).new("{}") }
    KnoxTrain::Restic::Status.new(make_profile, make_backend, commands: obj).fetch
    # Third exec is raw_stats_cmd — must include --mode raw-data
    assert_match(/--mode raw-data/, executed[2])
  end

  # ── fetch_verbose ────────────────────────────────────────────────────────

  def test_fetch_verbose_returns_raw_strings
    cmds = fake_commands_sequence("snap output", "stats output", "raw output")
    result = KnoxTrain::Restic::Status.new(make_profile, make_backend, commands: cmds).fetch_verbose
    assert_equal "snap output",  result[:snapshots]
    assert_equal "stats output", result[:stats]
    assert_equal "raw output",   result[:raw]
  end

  def test_fetch_verbose_omits_json_flag
    executed = []
    obj = Object.new
    obj.define_singleton_method(:exec) { |cmd, **_opts| executed << cmd; Struct.new(:out).new("") }
    KnoxTrain::Restic::Status.new(make_profile, make_backend, commands: obj).fetch_verbose
    refute executed.any? { |cmd| cmd.include?("--json") }
  end

  # ── Env var management ───────────────────────────────────────────────────

  def test_password_set_during_fetch
    password_seen = nil
    obj = Object.new
    # Returns "{}" — safe for all three parse paths (see note above).
    obj.define_singleton_method(:exec) do |_cmd, **_opts|
      password_seen ||= ENV["RESTIC_PASSWORD"]
      Struct.new(:out).new("{}")
    end
    KnoxTrain::Restic::Status.new(make_profile, make_backend, commands: obj).fetch
    assert_equal "testpass", password_seen
  end

  def test_password_restored_after_fetch
    original = ENV["RESTIC_PASSWORD"]
    ENV.delete("RESTIC_PASSWORD")
    obj = Object.new
    obj.define_singleton_method(:exec) { |_cmd, **_opts| Struct.new(:out).new("{}") }
    KnoxTrain::Restic::Status.new(make_profile, make_backend, commands: obj).fetch
    assert_nil ENV["RESTIC_PASSWORD"]
  ensure
    original.nil? ? ENV.delete("RESTIC_PASSWORD") : ENV["RESTIC_PASSWORD"] = original
  end

  # ── Hook invocation ──────────────────────────────────────────────────────

  def test_fetch_calls_run_before_hooks
    called = []
    backend = make_backend(run_befores: [-> { called << :before }])
    cmds = fake_commands_sequence(SNAPSHOTS_JSON, STATS_JSON, RAW_JSON)
    KnoxTrain::Restic::Status.new(make_profile, backend, commands: cmds).fetch
    assert_includes called, :before
  end

  def test_fetch_calls_run_after_hooks
    called = []
    backend = make_backend(run_afters: [-> { called << :after }])
    cmds = fake_commands_sequence(SNAPSHOTS_JSON, STATS_JSON, RAW_JSON)
    KnoxTrain::Restic::Status.new(make_profile, backend, commands: cmds).fetch
    assert_includes called, :after
  end

  def test_fetch_calls_run_after_hooks_on_error
    called = []
    backend = make_backend(run_afters: [-> { called << :after }])
    obj = Object.new
    result_stub = Struct.new(:exit_status, :out, :err).new(1, "", "restic failed")
    obj.define_singleton_method(:exec) { |_cmd, **_| raise TTY::Command::ExitError.new("restic", result_stub) }
    assert_raises(TTY::Command::ExitError) do
      KnoxTrain::Restic::Status.new(make_profile, backend, commands: obj).fetch
    end
    assert_includes called, :after
  end

  def test_fetch_verbose_calls_run_before_and_after_hooks
    called = []
    backend = make_backend(
      run_befores: [-> { called << :before }],
      run_afters:  [-> { called << :after  }]
    )
    cmds = fake_commands_sequence("snap output", "stats output", "raw output")
    KnoxTrain::Restic::Status.new(make_profile, backend, commands: cmds).fetch_verbose
    assert_equal [:before, :after], called
  end
end
