require "thor"
require "knox_train/version"

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
      raise NotImplementedError, "backup is implemented in Phase 4"
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
      raise NotImplementedError, "validate is implemented in Phase 2"
    end

    desc "show PROFILE", "Dump resolved config for a profile"
    def show(_profile)
      raise NotImplementedError, "show is implemented in Phase 2"
    end
  end
end
