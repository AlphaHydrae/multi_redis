module MultiRedis

  class Data < Hash

    def method_missing symbol, *args, &block
      if args.empty?
        self[symbol]
      elsif args.length == 1 && m = symbol.to_s.match(/\A(.*)\=\Z/)
        acc = m[1].to_sym
        raise ArgumentError, "Cannot set property #{acc}, method ##{acc} already exists" if respond_to? acc
        self[acc] = args[0]
      else
        super symbol, *args, &block
      end
    end
  end
end
