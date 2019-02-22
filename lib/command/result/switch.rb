module Command
  module Result

    # An object which is initialized with a block that defines callbacks to be
    # used based on a certain Result
    #
    # Then, passed a result, it will invoke the correct callback.
    #
    #     result_handler = Command::Result::Switch.new do
    #       ok do |value|
    #         # Called on success result
    #       end
    #
    #       error(:some_code) do |payload|
    #         # Called when specific error occurs
    #       end
    #
    #       error do |code, payload|
    #         # Called on any kind of declared error
    #       end
    #
    #       exception(SomeError) do |e|
    #         # Called for any SomeError (or sub-class) raised
    #         # during command
    #       end
    #
    #       exception do |e|
    #         # Same as above, but implicitly for StandardError
    #       end
    #
    #       # If no exception handler for a raised exception is
    #       # found, it is re-raised to the caller of the command
    #
    #       any do |result|
    #         # Called for any success or failure, IFF another
    #         # callback didn't match
    #         #
    #         # NOT called for unhandled exceptions (they are re-raised)
    #         #
    #         # Preferably, just call `Result#map` instead of using this if its
    #         # the only handler you're defining.
    #       end
    #     end
    #
    #     result_handler.switch(some_result) # Calls correct handler
    #
    # Exactly one callback will be called (the most specific) or an exception
    # will be raised.
    #
    # The scope inside the handler definition is very minimal but the scope
    # inside the handler blocks themselves will be the same as the caller (e.g.
    # a controller)
    #
    class Switch
      def initialize(&handler_definitions)
        raise ArgumentError, 'block required' unless block_given?

        # Capture the scope of the caller, so it can be applied to handler blocks
        @caller = handler_definitions.binding.eval("self")

        @handlers = define_handlers(handler_definitions)
      end

      def call(result)
        if result.success?
          handle_success(result)
        else
          handle_failure(result)
        end
      end

      private

      # Either calls the `ok` handler or the fallback.
      #
      # Raises if neither is defined.
      #
      def handle_success(result)
        if (handler = @handlers[:ok])
          @caller.instance_exec(result.value, &handler)
        elsif (handler = @handlers[:fallback])
          @caller.instance_exec(result, &handler)
        else
          raise ArgumentError, "No success handler or fallback defined"
        end
      end

      # Either calls the `error(code)`, `error`, or the fallback.
      #
      # Raises if none of the above is defined.
      #
      # If the failure is due to an unexpected exception, it delegates to the
      # exception handler.
      def handle_failure(result)
        return handle_exception(result) if result.code == :exception

        if (handler = @handlers[:error][result.code])
          @caller.instance_exec(result.payload, &handler)
        elsif (handler = @handlers[:error][:fallback])
          @caller.instance_exec(result.code, result.payload, &handler)
        elsif (handler = @handlers[:fallback])
          @caller.instance_exec(result, &handler)
        else
          raise ArgumentError, "No failure handler or fallback defined for #{result.code}"
        end
      end

      # Calls the most-specific `exception` handler that specifies the
      # exception class or one of it's ancestors
      #
      # If no ancestor handler (including the generic `exception` handler) is
      # found, then it re-raises the original exception.
      #
      def handle_exception(result)
        exception = result.cause
        handlers = @handlers[:exception]
        ancestors = exception.class.ancestors.
          select { |klass| klass.ancestors.include?(::Exception) }

        ancestors.each do |klass|
          if handlers.key?(klass)
            handler = handlers[klass]
            return @caller.instance_exec(exception, &handler)
          end
        end

        raise exception
      end

      # Creates a disposable binding for defining result handlers and invokes
      # the `Switch`'s definition block in its context.'
      #
      # Returns the `Hash` of handlers.
      #
      def define_handlers(definitions)
        handlers = {
          error: {},
          exception: {},
        }

        # This is a bit "meta" because we want the block definition to be able
        # to call methods like `ok`, `error`, but those methods need to close over
        # the handlers hash (above) in order to add to it. If it were a normal
        # class, we'd have to expose access to the handlers to outside, which
        # defeats the purpose of using a BasicObject here so the handler
        # definition block has a very small interface.
        binding = Class.new(BasicObject) do
          define_method(:ok) do |&handler|
            ::Kernel.raise ::ArgumentError, "No block given" unless handler
            handlers[:ok] = handler
          end

          define_method(:error) do |code=nil, &handler|
            ::Kernel.raise ::ArgumentError, "No block given" unless handler
            handlers[:error][code || :fallback] = handler
          end

          define_method(:exception) do |klass=StandardError, &handler|
            ::Kernel.raise ::ArgumentError, "No block given" unless handler
            handlers[:exception][klass] = handler
          end

          define_method(:any) do |&handler|
            ::Kernel.raise ::ArgumentError, "No block given" unless handler
            handlers[:fallback] = handler
          end
        end.new

        # Run the passed in definition block in the context of our magic
        # definer binding, which will update the handlers hash.
        binding.instance_exec(binding, &definitions)

        if handlers.values.all?(&:blank?)
          raise ArgumentError, "No handlers defined"
        end

        # This hash has now been with the handler callbacks needed to handler a
        # result later.
        handlers
      end
    end
  end
end
