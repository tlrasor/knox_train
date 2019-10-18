require "knox_train/version"

require "knox_train/utils"

require "knox_train/notifications"
require "knox_train/timer"

require "knox_train/connection_test"
require "knox_train/rsync"

require "knox_train/driver"


module KnoxTrain

  # Starts the train!
  def giddyup! **opts, &block
    Driver.new(opts).drive(&block)
  end
end

extend KnoxTrain if self.to_s == "main"