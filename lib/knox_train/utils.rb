module KnoxTrain
  module Utils
    def abort! msg
      abort(format_log_message(msg))
    end

    def which?(cmd)
      exts = ENV['PATHEXT'] ? ENV['PATHEXT'].split(';') : ['']
      ENV['PATH'].split(File::PATH_SEPARATOR).each do |path|
        exts.each { |ext|
          exe = File.join(path, "#{cmd}#{ext}")
          return exe if File.executable?(exe) && !File.directory?(exe)
        }
      end
      return nil
    end

    def format_log_message msg
      "#{Time.now}: #{msg}"
    end
  end

  extend KnoxTrain::Utils
end

