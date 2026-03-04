require "test_helper"

class DslTest < Minitest::Test

  # ── ConfigContext ──────────────────────────────────────────────────────────

  def make_ctx(&block)
    ctx = KnoxTrain::DSL::ConfigContext.new
    ctx.instance_eval(&block) if block
    ctx
  end

  def test_profile_declaration
    ctx = make_ctx do
      profile :documents do
        source "~/Documents"
        backend :b2 do
          repo "b2:bucket:docs"
          password { "secret" }
        end
      end
    end
    assert_includes ctx.profiles.keys, :documents
    p = ctx.profiles[:documents]
    assert_equal :documents, p.name
    assert_equal ["~/Documents"], p.sources
  end

  def test_duplicate_profile_raises
    assert_raises(KnoxTrain::DSL::UnknownKeyError) do
      make_ctx do
        profile(:dup) { source "/tmp"; backend(:b2) { repo "b2:x:y"; password { "" } } }
        profile(:dup) { source "/tmp"; backend(:b2) { repo "b2:x:y"; password { "" } } }
      end
    end
  end

  def test_group_declaration
    ctx = make_ctx do
      group :all, [:documents, :photos]
    end
    assert_equal %i[documents photos], ctx.groups[:all]
  end

  def test_global_declaration
    ctx = make_ctx { global { priority :low; notifications false } }
    assert_equal :low, ctx.global.priority
    assert_equal false, ctx.global.notifications
  end

  def test_ssh_server_returns_instance
    ctx = make_ctx {}
    server = ctx.ssh_server(host: "nas.local", user: "admin", mac: "00:00:00:00:00:00")
    assert_instance_of KnoxTrain::SshServer, server
    assert_equal "nas.local", server.host
  end

  def test_unknown_top_level_key_raises
    assert_raises(KnoxTrain::DSL::UnknownKeyError) do
      make_ctx { typo_keyword "value" }
    end
  end

  # ── ProfileDSL ────────────────────────────────────────────────────────────

  def test_profile_source_string
    ctx = make_ctx do
      profile(:p) { source "~/Documents"; backend(:b2) { repo "b2:x:y"; password { "" } } }
    end
    assert_equal ["~/Documents"], ctx.profiles[:p].sources
  end

  def test_profile_source_block
    ctx = make_ctx do
      profile(:p) { source { "/tmp/photos" }; backend(:b2) { repo "b2:x:y"; password { "" } } }
    end
    assert_kind_of Proc, ctx.profiles[:p].sources.first
  end

  def test_profile_multiple_backends
    ctx = make_ctx do
      profile(:p) do
        source "/tmp"
        backend(:sftp) { repo "sftp:host:/path"; password { "" } }
        backend(:b2)   { repo "b2:bucket:p";     password { "" } }
      end
    end
    assert_equal 2, ctx.profiles[:p].backends.length
    assert_equal %i[sftp b2], ctx.profiles[:p].backends.map(&:type)
  end

  def test_unknown_profile_key_raises
    assert_raises(KnoxTrain::DSL::UnknownKeyError) do
      make_ctx { profile(:p) { soruce "~/Documents" } }
    end
  end

  # ── BackendDSL ────────────────────────────────────────────────────────────

  def test_backend_retention_stored
    ctx = make_ctx do
      profile(:p) do
        source "/tmp"
        backend(:b2) { repo "b2:x:y"; password { "" }; retention daily: 7, weekly: 8 }
      end
    end
    ret = ctx.profiles[:p].backends.first.retention
    assert_equal 7, ret[:daily]
    assert_equal 8, ret[:weekly]
  end

  def test_backend_retention_unknown_key_raises
    assert_raises(KnoxTrain::DSL::UnknownKeyError) do
      make_ctx do
        profile(:p) do
          source "/tmp"
          backend(:b2) { repo "b2:x:y"; password { "" }; retention typo: 7 }
        end
      end
    end
  end

  def test_backend_hooks_stored_as_procs
    run_before_called = false
    ctx = make_ctx do
      profile(:p) do
        source "/tmp"
        backend(:sftp) do
          repo "sftp:host:/path"
          password { "" }
          run_before { run_before_called = true }
          run_after  { }
        end
      end
    end
    b = ctx.profiles[:p].backends.first
    assert_equal 1, b.run_befores.length
    assert_equal 1, b.run_afters.length
    assert_kind_of Proc, b.run_befores.first
  end

  def test_unknown_backend_key_raises
    assert_raises(KnoxTrain::DSL::UnknownKeyError) do
      make_ctx do
        profile(:p) { source "/tmp"; backend(:b2) { repo "b2:x:y"; typo_key "val" } }
      end
    end
  end

  # ── GlobalDSL ─────────────────────────────────────────────────────────────

  def test_unknown_global_key_raises
    assert_raises(KnoxTrain::DSL::UnknownKeyError) do
      make_ctx { global { typo_key :value } }
    end
  end
end
