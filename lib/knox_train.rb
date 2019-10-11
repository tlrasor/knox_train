require "knox_train/version"

require "knox_train/shell"
require "knox_train/logger"
require "knox_train/notifications"
require "knox_train/timer"

require "knox_train/connection_test"
require "knox_train/rsync"


module KnoxTrain

  def self.train &block
    Train.start_timer
    Train.log "Starting train"
    begin
      Train.module_eval &block
    rescue Error => e
      Train.log_error "Encountered error processing train: #{e}"
      exit 1
    end
    Train.log "Train arrived successfully in #{Train.stop_timer}"

  end

  module Train
    extend KnoxTrain::Logger
    extend KnoxTrain::Notifications
    extend KnoxTrain::Notifications
    extend KnoxTrain::Timer
    extend KnoxTrain::ConnectionTest
    extend KnoxTrain::Rsync
  end
end