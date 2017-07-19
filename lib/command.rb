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

      code, value = catch(:err) do
        begin
          result = callable.call
          return handle.(result) if result.is_a?(Command::Result)
          [:ok, result]
        rescue => e
          if block_given?
            # Let the switcher provide an avenue for handling this error. If it
            # doesn't, it will re-raise anyway.
            throw :err, [:exception, e]
          else
            raise
          end
        end
      end

      if code == :ok
        handle.(Success.new(value))
      elsif code == :exception
        handle.(Failure.new(code: code, cause: value))
      else
        handle.(Failure.new(code: code, payload: value))
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
      err = catch(:err) { return block.call }
      raise ActiveRecord::Rollback
    end
    throw(:err, err) if err
  end

  def err!(code = :error, value = nil)
    throw :err, [code, value]
  end
end
