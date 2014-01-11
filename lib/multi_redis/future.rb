module MultiRedis

  class FutureNotReady < RuntimeError
    
      def initialize
        super "Value will be available once the operation executes."
      end
    end

  class Future
    FutureNotReady = ::MultiRedis::FutureNotReady.new
    attr_writer :value
    
    def initialize value = nil
      @value = value || FutureNotReady
    end

    def value
      raise @value if @value.kind_of? RuntimeError
      @value
    end
  end
end
