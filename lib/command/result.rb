#
# Ideally this `Result` concept is top-level and not at all `Command`-specific,
# but `Result` is already a ActiveRecord model in this app so the constant is
# taken. Eventually, the model concept might have a better name and this one
# can be promoted to the top-level.
#
class Command

  # `Result` is included into `Success` and `Failure`.
  #
  # Defines the common interface and allows both result types to register as a
  # `Result` with `#is_a?`.
  #
  # Not a superclass, because `Failure` needs to inherit from an exception to be
  # `raise`-able.
  module Result
    def success?
      false
    end

    def failure?
      false
    end

    def map(&block)
      raise NotImplementedError
    end

    def value
      raise NotImplementedError
    end

    def inspect
      "#<Result>"
    end
  end


  # `Success` wraps the successful outcome value of some operation.
  #
  # The value can be accessed with `#value` or by block with `#map`.
  class Success
    include Result

    attr_reader :value

    def initialize(value = nil)
      @value = value
    end

    def success?
      true
    end

    def map(&block)
      block.call(value)
    end

    def inspect
      value = self.value.present? && " #{self.value.inspect}"
      "#<Success#{value}>"
    end
  end

  # `Failure` represents a failed outcome for some operation.
  #
  # It is also an exception so can be raised (e.g. when triggering an operation
  # to return it's value directly.)
  #
  # Calling `#map` is a no-op (block is not called), so you can safely call
  # `Result#map` regardless of the result type.
  #
  # Attempting to access the result value with `#value` will cause the `Failure`
  # to `raise` itself.
  class Failure < RuntimeError
    include Result

    attr_reader :code, :payload

    def initialize(code: :error, payload: {}, cause: nil, message: nil, i18n: I18n)
      @code, @payload, @cause = code, payload, cause

      message ||= i18n.translate(code, {
        locale: :en,
        scope: [:errors],
        **(payload.is_a?(Hash) ? payload : {})
      })

      super(message)
    end

    def failure?
      true
    end

    def map
      # no-op
    end

    # :nodoc:
    #
    # We let the cause be explicitly passed in here so that we can wrap an
    # exception in a failure without raising it. Ruby only sets an exception's
    # cause when it is `raise`d and existing exception is in scope in `$!`:
    #
    #     begin
    #       raise
    #     rescue
    #       Failure.new
    #     end.cause          # => nil
    #
    #     begin
    #       raise
    #     rescue
    #       begin
    #         raise Failure
    #       rescue => e
    #         e
    #       end
    #     end.cause          # => RuntimeError
    #
    def cause
      @cause || super
    end

    def value
      if cause
        raise cause
      else
        raise self
      end
    end

    def inspect
      "#<Failure code=#{code}>"
    end
  end
end
