# frozen_string_literal: true

module KnoxTrain
  Profile = Struct.new(:name, :sources, :exclude_files, :tags, :host, :backends)

  Backend = Struct.new(:type, :repo, :password, :retention, :run_befores, :run_afters,
                       :env_credentials) do
    def initialize(**kwargs)
      kwargs[:env_credentials] ||= {}
      super
    end
  end
end
