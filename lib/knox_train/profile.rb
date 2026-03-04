module KnoxTrain
  Profile = Struct.new(:name, :sources, :exclude_files, :tags, :host, :backends,
                       keyword_init: true)

  Backend = Struct.new(:type, :repo, :password, :retention, :run_befores, :run_afters,
                       :env_credentials, keyword_init: true) do
    def initialize(**kwargs)
      kwargs[:env_credentials] ||= {}
      super(**kwargs)
    end
  end
end
