require "test_helper"

class ProfileTest < Minitest::Test
  def test_profile_struct_fields
    b = KnoxTrain::Backend.new(
      type: :b2, repo: "b2:bucket:docs", password: nil,
      retention: { daily: 7 }, run_befores: [], run_afters: [], env_credentials: {}
    )
    p = KnoxTrain::Profile.new(
      name: :documents, sources: ["~/Documents"], exclude_files: [],
      tags: ["docs"], host: true, backends: [b]
    )
    assert_equal :documents, p.name
    assert_equal ["~/Documents"], p.sources
    assert_equal true, p.host
    assert_equal 1, p.backends.length
    assert_equal :b2, p.backends.first.type
    assert_equal "b2:bucket:docs", p.backends.first.repo
    assert_equal({ daily: 7 }, p.backends.first.retention)
    assert_equal({}, p.backends.first.env_credentials)
  end

  def test_backend_password_stores_proc
    proc_val = -> { "secret" }
    b = KnoxTrain::Backend.new(
      type: :sftp, repo: "sftp:host:/path", password: proc_val,
      retention: nil, run_befores: [], run_afters: []
    )
    assert_equal proc_val, b.password
    assert_kind_of Proc, b.password
  end

  def test_backend_env_credentials_defaults_to_empty_hash
    b = KnoxTrain::Backend.new(
      type: :b2, repo: "b2:x:y", password: nil,
      retention: nil, run_befores: [], run_afters: []
    )
    assert_equal({}, b.env_credentials)
  end

  def test_backend_env_credentials_stores_procs
    key_proc = -> { "key-value" }
    b = KnoxTrain::Backend.new(
      type: :b2, repo: "b2:x:y", password: nil,
      retention: nil, run_befores: [], run_afters: [],
      env_credentials: { "AWS_ACCESS_KEY_ID" => key_proc }
    )
    assert_equal 1, b.env_credentials.length
    assert_equal key_proc, b.env_credentials["AWS_ACCESS_KEY_ID"]
    assert_kind_of Proc, b.env_credentials["AWS_ACCESS_KEY_ID"]
  end
end
