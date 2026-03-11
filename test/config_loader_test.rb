# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'

class ConfigLoaderTest < Minitest::Test
  def teardown
    # Restore KNOX_CONFIG if a test set it
    ENV.delete('KNOX_CONFIG')
  end

  def test_find_returns_nil_when_no_file_exists
    result = KnoxTrain::ConfigLoader.find(explicit_path: '/nonexistent/path/config.rb')
    assert_nil result
  end

  def test_find_explicit_path_wins
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'myconfig.rb')
      File.write(path, '')
      assert_equal path, KnoxTrain::ConfigLoader.find(explicit_path: path)
    end
  end

  def test_find_env_var_wins_over_defaults
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'env_config.rb')
      File.write(path, '')
      ENV['KNOX_CONFIG'] = path
      assert_equal path, KnoxTrain::ConfigLoader.find
    end
  end

  def test_load_raises_on_syntax_error
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'bad.rb')
      File.write(path, 'def bad syntax !!!')
      assert_raises(KnoxTrain::ConfigLoader::Error) do
        KnoxTrain::ConfigLoader.load(path)
      end
    end
  end

  def test_load_evaluates_file
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'config_loader_test.rb')
      File.write(path, <<~RUBY)
        KnoxTrain.configure do
          profile :loader_test do
            source '/tmp'
            backend :b2 do
              repo 'b2:bucket:loader_test'
              password { 'secret' }
            end
          end
        end
      RUBY
      KnoxTrain::ConfigLoader.load(path)
      assert_includes KnoxTrain.registry.profiles.keys, :loader_test
    end
  end
end
