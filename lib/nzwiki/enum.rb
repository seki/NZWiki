module Enumerable
  def slice(nth, len)
    return to_enum(__method__, nth, len) unless block_given?
    each do |*arg|
      break if len <= 0
      if nth >= 1
        nth -= 1
        next
      end
      len -= 1
      yield(*arg)
    end
  end
end
