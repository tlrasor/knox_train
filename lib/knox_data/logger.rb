module KnoxTrain
  module Logger
    def log message
      puts "#{Time.now}: #{message}"
    end

    def log_error message
      STDERR.puts "#{Time.now}: #{message}"
    end
  end
end