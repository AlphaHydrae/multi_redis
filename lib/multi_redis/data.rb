
module MultiRedis

  class Data
    attr_reader :contents

    def initialize
      @contents = Hash.new
    end

    def [] k
      @contents[k]
    end

    def []= k, v
      @contents[k.to_sym] = v
    end

    def method_missing symbol, *args, &block
      if @contents.key? symbol
        @contents[symbol]
      elsif m = symbol.to_s.match(/\A(.*)\=\Z/)
        raise "Reserved name" if respond_to? acc = m[1].to_sym
        @contents[acc] = args[0]
      else
        super symbol, *args, &block
      end
    end
  end
end
