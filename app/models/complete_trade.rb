class CompleteTrade < ActiveRecord::Base

  class << self
    def trade_result(type, id)
      type = case type
      when "sell" then :ask
      when :sell then :ask
      when "buy" then :buy
      when "ask" then :ask
      end

      MtGox.order_result(type, id)
    end
  end
end
