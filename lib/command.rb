require 'command/result'
require 'command/result/switch'
require 'command/piped'

module Command
  class << self
    def included(klass)
      klass.extend Command::ClassMethods
    end

    def wrap_call(callable:, &block)
      handle = block_given? ?
        Result::Switch.new(&block) :
        ->(result) { result }

      result = begin
        callable.call
      rescue => e
        e
      end

      case result
      when Command::Result
        handle.(result)
      when Exception
        if block_given?
          handle.(Failure.new(code: :exception, cause: result))
        else
          raise result
        end
      else
        handle.(Success.new(result))
      end
    end
  end

  module ClassMethods
    def call(*args, **options, &block)
      Command.wrap_call(callable: new(*args, **options), &block)
    end
  end

  def call
    # Implement me
  end

  def |(other_command)
    Piped.new(self, other_command)
  end

  private

  # A transaction helper which _defaults_ to creating a nested transaction
  # (unlike ActiveRecord) and rolls back when an err result is returned.
  def transaction(requires_new: true, &block)
    err = nil
    ActiveRecord::Base.transaction(requires_new: requires_new) do
      begin
        return block.call
      rescue Failure => e
        err = e
        raise ActiveRecord::Rollback
      end
    end
    raise err if err
  end

  def err!(code = :error, value = nil)
    error = Failure.new(code: code, payload: value)
    on_error(error) if respond_to?(:on_error, true)
    raise error
  end
end
