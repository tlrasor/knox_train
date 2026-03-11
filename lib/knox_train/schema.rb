# frozen_string_literal: true

require 'dry-schema'

module KnoxTrain
  module Schema
    VALID_BACKEND_TYPES = %i[sftp b2 s3].freeze

    # Validates the serializable fields of a Backend (strips proc fields before calling).
    # Call as: BackendSchema.call(type: :b2, repo: "...", retention: {...})
    BackendSchema = Dry::Schema.define do
      required(:type).filled(:symbol)
      required(:repo).filled(:string)
      optional(:retention).hash do
        optional(:daily).filled(:integer)
        optional(:weekly).filled(:integer)
        optional(:monthly).filled(:integer)
        optional(:yearly).filled(:integer)
      end
    end

    # Validates the top-level profile structure.
    # Pass sources and backends as arrays (procs allowed as elements — not inspected).
    # Call as: ProfileSchema.call(name: :docs, sources: [...], backends: [...], ...)
    ProfileSchema = Dry::Schema.define do
      required(:name).filled(:symbol)
      required(:sources).filled(:array)    # non-empty; elements may be String or Proc
      optional(:exclude_files).array(:string)
      optional(:tags).array(:string)
      optional(:host).filled(:bool)
      required(:backends).filled(:array)   # non-empty; elements are Backend structs
    end
  end
end
