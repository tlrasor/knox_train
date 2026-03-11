# frozen_string_literal: true

require 'test_helper'

class SchemaTest < Minitest::Test
  def test_valid_backend
    result = KnoxTrain::Schema::BackendSchema.call(
      type: :sftp, repo: 'sftp:admin@nas.local:/share/restic/docs'
    )
    assert result.success?, result.errors.to_h.inspect
  end

  def test_valid_backend_with_retention
    result = KnoxTrain::Schema::BackendSchema.call(
      type: :b2, repo: 'b2:bucket:docs',
      retention: { daily: 7, weekly: 8, monthly: 24, yearly: 10 }
    )
    assert result.success?, result.errors.to_h.inspect
  end

  def test_missing_repo_fails
    result = KnoxTrain::Schema::BackendSchema.call(type: :b2)
    refute result.success?
    assert result.errors.to_h.key?(:repo)
  end

  def test_empty_repo_fails
    result = KnoxTrain::Schema::BackendSchema.call(type: :b2, repo: '')
    refute result.success?
  end

  def test_missing_type_fails
    result = KnoxTrain::Schema::BackendSchema.call(repo: 'b2:bucket:docs')
    refute result.success?
    assert result.errors.to_h.key?(:type)
  end

  def test_valid_profile
    result = KnoxTrain::Schema::ProfileSchema.call(
      name: :documents, sources: ['~/Documents'], backends: [:placeholder]
    )
    assert result.success?, result.errors.to_h.inspect
  end

  def test_empty_sources_fails
    result = KnoxTrain::Schema::ProfileSchema.call(
      name: :documents, sources: [], backends: [:placeholder]
    )
    refute result.success?
  end

  def test_empty_backends_fails
    result = KnoxTrain::Schema::ProfileSchema.call(
      name: :documents, sources: ['~/Documents'], backends: []
    )
    refute result.success?
  end

  def test_missing_name_fails
    result = KnoxTrain::Schema::ProfileSchema.call(
      sources: ['~/Documents'], backends: [:placeholder]
    )
    refute result.success?
  end
end
