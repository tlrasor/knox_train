require 'chronic_duration'

module KnoxTrain
  class Timer
    def initialize
      @timer_start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
    
    def elapsed pretty: true
      diff = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - @timer_start).to_i
      if pretty
        ChronicDuration.output(diff, :keep_zero => true, :format => :short)
      else
        diff
      end
    end
  end
end