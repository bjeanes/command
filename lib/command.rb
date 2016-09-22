require 'command/result'
require 'command/result/switch'

class Command
  class << self
    def call(**options, &block)
      handle = block_given? ?
        Result::Switch.new(&block) :
        ->(result) { result }

      code, result = catch(:err) do
        begin
          [:ok, new(**options).call]
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
        handle.(Success.new(result))
      elsif code == :exception
        handle.(Failure.new(code: code, cause: result))
      else
        handle.(Failure.new(code: code, payload: result))
      end
    end
  end

  def initialize(**options)
  end

  def call
    # Implement me
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
    throw :err, err
  end

  def err!(code = :error, value = nil)
    throw :err, [code, value]
  end
end
