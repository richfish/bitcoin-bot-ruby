class PagesController < ApplicationController
  def index
    @completed_trades = CompleteTrade.all.order("created_at DESC")
    @current_price    = PriceEntry.last.price.to_f
  end

  def price_log
    @log = Rails.cache.read 'price_logs'
  end

  def position_log
    @log = Rails.cache.read 'position_logs'
  end

  protected

  def log(type) #for writing to file system if opting to do that
    file     = Rails.env == "development" ? "#{Rails.root}/log/#{type}_dev.log" : "#{Rails.root}/lib/#{type}_prod.txt"
    raw_log  = %x[tail -n 600 #{file}]
    @raw_log = raw_log.scan(/\-\-(.+)\-\-/).reverse
  end

end
