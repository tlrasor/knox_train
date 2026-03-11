# frozen_string_literal: true

module KnoxTrain
  module Utils
    def abort!(msg)
      abort(format_log_message(msg))
    end

    def which?(cmd)
      exts = ENV['PATHEXT'] ? ENV['PATHEXT'].split(';') : ['']
      ENV['PATH'].split(File::PATH_SEPARATOR).each do |path|
        exts.each do |ext|
          exe = File.join(path, "#{cmd}#{ext}")
          return exe if File.executable?(exe) && !File.directory?(exe)
        end
      end
      false
    end

    def format_log_message(msg)
      "#{Time.now}: #{msg}"
    end

    def count_files(dirs = [])
      dirs.inject(0) do |a, dir|
        a + Dir[File.join(dir, '**', '*')].count { |file| File.file?(file) }
      end
    end
  end

  extend KnoxTrain::Utils
end
