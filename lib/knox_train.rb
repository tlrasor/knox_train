require "knox_train/version"

require "knox_train/utils"

require "knox_train/notifications"
require "knox_train/timer"

require "knox_train/connection_test"
require "knox_train/rsync"

require "knox_train/commands"
require "knox_train/driver"

require "knox_train/ssh_server"
require "knox_train/volume"
require "knox_train/profile"
require "knox_train/secrets/keychain"
require "knox_train/secrets/env"
require "knox_train/dsl"
require "knox_train/schema"
require "knox_train/config_loader"
require "knox_train/restic/runner"
require "knox_train/restic/status"
require "knox_train/scheduler/launchd"


module KnoxTrain

  # Starts the train!
  def giddyup! **opts, &block
    Driver.new(opts).drive(&block)
  end

  class << self
    attr_reader :registry

    def configure(&block)
      ctx = DSL::ConfigContext.new
      ctx.instance_eval(&block)
      ctx.validate!
      @registry = ctx
    end
  end
end

extend KnoxTrain if self.to_s == "main"