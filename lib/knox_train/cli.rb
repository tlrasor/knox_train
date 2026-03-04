require "thor"
require "knox_train/version"
require "knox_train/config_loader"
require "knox_train/dsl"
require "knox_train/profile"
require "knox_train/schema"
require "knox_train/ssh_server"
require "knox_train/restic/runner"

module KnoxTrain
  class CLI < Thor
    def self.exit_on_failure? = true

    class_option :config, aliases: "-c", type: :string,
                          desc: "Path to config file (default: ./knox_train.rb)"

    desc "version", "Print knox version"
    def version
      puts "knox #{KnoxTrain::VERSION}"
    end

    desc "backup", "Run restic backups"
    option :profile, aliases: "-p", type: :string,  desc: "Profile name"
    option :backend, aliases: "-b", type: :string,  desc: "Backend (sftp, b2, s3)"
    option :all,                    type: :boolean, desc: "Run all profiles"
    option :prune,                  type: :boolean, desc: "Apply retention policy after backup"
    def backup
      path = options[:config] || KnoxTrain::ConfigLoader.find
      unless path
        say "No config file found. Use -c PATH to specify.", :red
        exit 1
      end
      KnoxTrain::ConfigLoader.load(path)
      reg = KnoxTrain.registry

      profiles = if options[:all]
                   reg.profiles.values
                 elsif options[:profile]
                   p = reg.profiles[options[:profile].to_sym]
                   unless p
                     say "Profile '#{options[:profile]}' not found.", :red
                     exit 1
                   end
                   [p]
                 else
                   say "Specify --profile NAME or --all", :red
                   exit 1
                 end

      backend_filter = options[:backend]&.to_sym
      prune          = options[:prune] || false
      had_error      = false

      profiles.each do |profile|
        backends = profile.backends
        backends = backends.select { |b| b.type == backend_filter } if backend_filter
        backends.each do |backend|
          KnoxTrain::Restic::Runner.new(profile, backend, prune: prune).run
        rescue KnoxTrain::DSL::SkipProfile => e
          say "Skipping #{profile.name}: #{e.message}", :yellow
        rescue TTY::Command::ExitError => e
          say "✗ #{profile.name}/#{backend.type}: #{e.message}", :red
          had_error = true
        end
      end

      exit 1 if had_error
    rescue KnoxTrain::DSL::UnknownKeyError, KnoxTrain::DSL::ValidationError,
           KnoxTrain::ConfigLoader::Error => e
      say "✗ #{e.message}", :red
      exit 1
    end

    desc "status", "Show snapshot status"
    option :backend, aliases: "-b", type: :string,  desc: "Backend (sftp, b2, s3)"
    option :verbose, aliases: "-v", type: :boolean, desc: "Full restic output"
    def status
      raise NotImplementedError, "status is implemented in Phase 5"
    end

    desc "schedule", "Install launchd backup schedule"
    option :profile, aliases: "-p", type: :string,  desc: "Profile name"
    option :all,                    type: :boolean, desc: "Schedule all profiles"
    def schedule
      raise NotImplementedError, "schedule is implemented in Phase 6"
    end

    desc "unschedule", "Remove launchd backup schedule"
    option :profile, aliases: "-p", type: :string,  desc: "Profile name"
    option :all,                    type: :boolean, desc: "Unschedule all profiles"
    def unschedule
      raise NotImplementedError, "unschedule is implemented in Phase 6"
    end

    desc "validate", "Validate config file (no I/O, no restic)"
    def validate
      path = options[:config] || KnoxTrain::ConfigLoader.find
      unless path
        say "No config file found. Use -c PATH to specify.", :red
        exit 1
      end
      KnoxTrain::ConfigLoader.load(path)
      reg = KnoxTrain.registry
      say "Config: #{path}"
      say "Profiles: #{reg.profiles.keys.join(', ')}"
      say "Groups:   #{reg.groups.keys.join(', ')}" unless reg.groups.empty?
      say "✓ Config valid", :green
    rescue KnoxTrain::DSL::UnknownKeyError, KnoxTrain::DSL::ValidationError,
           KnoxTrain::ConfigLoader::Error => e
      say "✗ #{e.message}", :red
      exit 1
    end

    desc "show PROFILE", "Dump resolved config for a profile"
    def show(profile_name)
      path = options[:config] || KnoxTrain::ConfigLoader.find
      unless path
        say "No config file found. Use -c PATH to specify.", :red
        exit 1
      end
      KnoxTrain::ConfigLoader.load(path)
      profile = KnoxTrain.registry.profiles[profile_name.to_sym]
      unless profile
        say "Profile '#{profile_name}' not found.", :red
        exit 1
      end
      print_profile(profile)
    rescue KnoxTrain::DSL::UnknownKeyError, KnoxTrain::DSL::ValidationError,
           KnoxTrain::ConfigLoader::Error => e
      say "✗ #{e.message}", :red
      exit 1
    end

    private

    def print_profile(profile)
      puts "Profile: #{profile.name}"
      puts "  sources:"
      profile.sources.each { |s| puts "    - #{s.is_a?(Proc) ? '[block]' : s}" }
      puts "  exclude_files: #{profile.exclude_files&.join(', ').then { |v| v&.empty? ? '(none)' : v } || '(none)'}"
      puts "  tags: #{profile.tags&.join(', ') || '(none)'}"
      puts "  host: #{profile.host}"
      puts "  backends:"
      profile.backends.each do |b|
        puts "    #{b.type}:"
        puts "      repo:     #{b.repo}"
        puts "      password: #{b.password ? '[block]' : '(not set)'}"
        if b.retention
          kv = b.retention.map { |k, v| "#{k}=#{v}" }.join(" ")
          puts "      retention: #{kv}"
        end
        hooks = []
        hooks << "run_before: [#{b.run_befores.length} block(s)]" if b.run_befores&.any?
        hooks << "run_after: [#{b.run_afters.length} block(s)]"   if b.run_afters&.any?
        puts "      hooks: #{hooks.join(', ')}" unless hooks.empty?
      end
    end
  end
end
