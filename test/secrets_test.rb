require "test_helper"
require "minitest/mock"

class SecretsTest < Minitest::Test

  # ── Keychain ────────────────────────────────────────────────────────────

  def test_keychain_available_returns_boolean
    result = KnoxTrain::Secrets::Keychain.available?
    assert_includes [true, false], result
  end

  def test_keychain_fetch_raises_when_not_available
    KnoxTrain::Secrets::Keychain.stub(:available?, false) do
      err = assert_raises(KnoxTrain::Secrets::Error) do
        KnoxTrain::Secrets::Keychain.fetch("any-service")
      end
      assert_match(/not available/, err.message)
    end
  end

  def test_keychain_fetch_raises_on_command_failure
    fake_status = Struct.new(:success?).new(false)
    fake_result = ["", "SecKeychainItemCopyContent: The specified item could not be found", fake_status]

    KnoxTrain::Secrets::Keychain.stub(:available?, true) do
      Open3.stub(:capture3, fake_result) do
        err = assert_raises(KnoxTrain::Secrets::Error) do
          KnoxTrain::Secrets::Keychain.fetch("nonexistent-service")
        end
        assert_match(/Keychain lookup failed/, err.message)
        assert_match(/nonexistent-service/, err.message)
      end
    end
  end

  def test_keychain_fetch_returns_chomped_value_on_success
    fake_status = Struct.new(:success?).new(true)
    fake_result = ["hunter2\n", "", fake_status]

    KnoxTrain::Secrets::Keychain.stub(:available?, true) do
      Open3.stub(:capture3, fake_result) do
        result = KnoxTrain::Secrets::Keychain.fetch("restic-documents")
        assert_equal "hunter2", result
      end
    end
  end

  # ── Env ─────────────────────────────────────────────────────────────────

  def test_env_fetch_raises_when_var_absent
    ENV.delete("KNOX_TEST_SECRET_XYZ")
    err = assert_raises(KnoxTrain::Secrets::Error) do
      KnoxTrain::Secrets::Env.fetch("KNOX_TEST_SECRET_XYZ")
    end
    assert_match(/KNOX_TEST_SECRET_XYZ/, err.message)
    assert_match(/not set or empty/, err.message)
  end

  def test_env_fetch_raises_when_var_empty
    ENV["KNOX_TEST_SECRET_XYZ"] = ""
    assert_raises(KnoxTrain::Secrets::Error) do
      KnoxTrain::Secrets::Env.fetch("KNOX_TEST_SECRET_XYZ")
    end
  ensure
    ENV.delete("KNOX_TEST_SECRET_XYZ")
  end

  def test_env_fetch_returns_value_when_set
    ENV["KNOX_TEST_SECRET_XYZ"] = "s3cr3t"
    assert_equal "s3cr3t", KnoxTrain::Secrets::Env.fetch("KNOX_TEST_SECRET_XYZ")
  ensure
    ENV.delete("KNOX_TEST_SECRET_XYZ")
  end

  # ── Error ────────────────────────────────────────────────────────────────

  def test_secrets_error_is_standard_error
    assert KnoxTrain::Secrets::Error.ancestors.include?(StandardError)
  end

  def test_single_error_class_shared_between_modules
    # Requiring both modules must not create two separate Error constants
    require "knox_train/secrets/keychain"
    require "knox_train/secrets/env"
    assert_same KnoxTrain::Secrets::Error, KnoxTrain::Secrets::Error
  end
end
