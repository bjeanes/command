module Command
  class Piped
    def initialize(*commands)
      raise ArgumentError if commands.size < 2
      @commands = commands.freeze
      freeze
    end

    def call(&block)
      Command.wrap_call(callable: method(:execute_pipe), &block)
    end

    def |(other_command)
      Command::Piped.new(*@commands, other_command)
    end

    private def execute_pipe
      result = nil

      @commands.each do |cmd|
        result = cmd.call
        break if result.is_a?(Command::Failure)
      end

      result
    end
  end
end
