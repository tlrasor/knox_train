require "tty-command"
require "tty-which"

module KnoxTrain
  class Commands
    def initialize(printer: :pretty)
      @cmd         = TTY::Command.new(printer: printer)
      @nice_path   = TTY::Which.which("nice")
      @ionice_path = TTY::Which.which("ionice")
    end

    # Run a shell command. Raises TTY::Command::ExitError on non-zero exit.
    # Returns TTY::Command::Result (callers may inspect .out / .err).
    def exec(command, nice: false, ionice: false)
      @cmd.run(build(command, nice: nice, ionice: ionice))
    end

    private

    def build(command, nice: false, ionice: false)
      prefix = []
      if nice
        raise ":nice requested but nice not found on PATH" if @nice_path.nil?
        prefix << "#{@nice_path} -n 19"
      end
      if ionice
        raise ":ionice requested but ionice not found on PATH" if @ionice_path.nil?
        prefix << "#{@ionice_path} -c2 -n7"
      end
      (prefix + [command]).join(" ")
    end
  end
end
