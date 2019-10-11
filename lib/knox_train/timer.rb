require 'chronic_duration'

module KnoxTrain
  module Timer
    
    def start_timer
      @timer_start ||= Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def stop_timer pretty: true
      @timer_stop ||= Process.clock_gettime(Process::CLOCK_MONOTONIC)
      diff = (@timer_stop - start_timer).to_i
      if pretty
        ChronicDuration.output(diff, :keep_zero => true, :format => :short)
      else
        diff
      end
    end
  end
end