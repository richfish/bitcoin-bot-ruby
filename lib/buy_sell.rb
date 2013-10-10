class BuySell
  #in case you want to set up a consumer/client of this class
  attr_accessor :day_20, :day_5, :day_1, :hour_12, :hour_6, :hour_2, :hour_1, :minutes_30, :minutes_10, :current_price, :base_level, :amount,
                :complete_trade, :stop_level, :profit_margin, :stoch_2, :stoch_1, :stoch_data, :buy_in

  def initialize
    #because can't write to file system with Heroku
    @dc = Dalli::Client.new
    @dc.add 'position_logs', "<br /> <br /> **starting log session**", nil, { raw: true}
  end


############################################################################################
#constantly alternates between these two loops

  def buy_in_loop
    @entry_time = Time.now
    set_amount_and_check_balance
    loop do
      log_time_and_price
      set_and_log_indicator_ivars

      if lagging_indicators_green && leading_indicators_green
        set_buy_in
        break
      else
        @dc.prepend 'position_logs', "NOT BUYING IN YET ------------------------------------  <br /><br />"
        set_sleep_time #varies depending on state of indicators.
      end
    end
    manage_position_loop
  end

  def manage_position_loop
    @base_level    = @buy_in = @current_price
    @stop_level    = @base_level - 0.75
    @profit_margin = first_profit_margin
    i = 0
    loop do
      i += 1
      @current_price = PriceEntry.last.price.to_f
      log_current_stats(i)
      set_and_log_indicator_ivars

      if @current_price <= @stop_level
        sell_it_fast
        break
      end

      if @current_price >= (@base_level + @profit_margin)
        set_new_level
      end

      if indicators_have_gone_south
        #do something here if things get flat or was bad buy in?
      end
      sleep 10
    end
    buy_in_loop
  end

############################################################################################



  protected
  def set_new_level
     @dc.prepend 'position_logs', "<br /> NEW BASE!!! ------------------------------------ <br />"
     @base_level    = @current_price
     @stop_level    = @base_level - 0.75
     @profit_margin = later_profit_margin
  end

  def sell_it_fast
    @dc.prepend 'position_logs', "<br /> SELLLLLL!!!! ------------------------------------ #{@current_price} with profit of #{the_profit} <br />"
    attempts = 0
    begin
      sell_id = MtGox.sell! @amount, :market
      @dc.prepend 'position_logs', "<br /> SOLD SUCCESFULLY: #{sell_id}------------------------ <br />"
    rescue
      attempts += 1
      @dc.prepend 'position_logs', "<br /> SALE FAILED LETS TRY AGAIN "
      retry unless attempts > 10
      exit -1 #send alert email?
    end
    @complete_trade.sell     = begin
                                 MtGox.order_result(:ask, sell_id).trades.first.price.to_f
                               rescue
                                 @current_price
                               end
    @complete_trade.profit   = the_profit
    @complete_trade.duration = (Time.now - @complete_trade.created_at)/60
    @complete_trade.sell_id  = sell_id
    @complete_trade.save
  end

  def set_buy_in
    attempts = 0
    begin
       @dc.prepend 'position_logs', "<br /> BUYING IN!!!! ------------------------------------ <br /><br />"
       buy_id          = MtGox.buy! @amount, :market
       @current_price  = begin
                           MtGox.order_result(:bid, buy_id).trades.first.price.to_f #price you buy in at exactly; if fails, just last price saved.
                         rescue
                           PriceEntry.last.price.to_f
                         end
       @complete_trade = CompleteTrade.create(buy: @current_price, buy_id: buy_id)
    rescue
      attempts += 1
      @dc.prepend 'position_logs', '<br /> BUY FAILED LETS TRY AGAIN ---------------------- <br/ >'
      retry unless attempts > 10
      exit -1 #send alert email?
    end
  end

  def log_time_and_price
    @dc.prepend 'position_logs', "time in loop: #{(Time.now - @entry_time)/60} min <br /><br /><br /><br /><br />"
    @dc.prepend 'position_logs', "current time: #{Time.now} <br />"
    @dc.prepend 'position_logs', "current price: #{PriceEntry.last.price.to_f}<br />"
  end

  def set_amount_and_check_balance
    attempts = 0
    begin
      @balance   = MtGox.balance
      bitc, usd = @balance[0].amount.to_f, @balance[1].amount.to_f
      @amount   = 0.01#usd #or some fractoin of total avail money, #amt needs to be bitcoin

      @dc.prepend 'position_logs', "<br /> YOUR BALANCE: #{usd} USD, #{bitc}, BTC <br />"
      @dc.prepend 'position_logs', "<br /> SETTING BUY IN AMOUNT TO #{usd} USD"
    rescue
      attempts += 1
      @dc.prepend 'position_logs', "<br /> CANT CONNECT FOR BALANCE ------------------------------ <br />"
      retry unless attempts > 10
      exit -1 #send alert email?
    end
  end

  def indicators_have_gone_south
    #pending
  end

  def set_sleep_time
    if lagging_indicators_green && !leading_indicators_green
      @dc.prepend 'position_logs', " sleep time: 30 -------- "
      sleep 30
    elsif @hour_1 > @hour_2 &&  @minutes_30 > @hour_1 && @minutes_10 < @minutes_30
      @dc.prepend 'position_logs', " sleep time: 180 --------"
      sleep 180
    else
      @dc.prepend 'position_logs', " sleep time: 300 --------"
      sleep 300
    end
  end

  def leading_indicators_green
    @stoch_1 && @stoch_2
  end

  def lagging_indicators_green
    one_hour_beats_two_hour && thirty_min_beats_one_hour && ten_min_beats_thirty_min
  end

  def one_hour_beats_two_hour
    @hour_1 - @hour_2 > 0.10
  end

  def thirty_min_beats_one_hour
    @minutes_30 - @hour_1 > 0.20  #hard to change, might want to make more flexible...
  end

  def ten_min_beats_thirty_min
    @minutes_10 - @minutes_30 > 0.25
  end

  def compute_stochastic(arr)
    arr.map!{ |p| p.price.to_f }
    unless arr.compact.blank? #recurring, mysterious error wit bunch of nil values
      @stoch_data ||= []
      @stoch_data << [arr.max, arr.min, arr.last]
      arr.last >= arr.max - ((arr.max - arr.min) * 0.33) #closing price should be in upper third of range for set
    end
  end

  def the_profit
    @current_price - @complete_trade.buy.to_f - the_fee
  end

  def distance_to_next_base
    next_base_level - @current_price
  end

  def next_base_level
    @base_level + @profit_margin
  end

  def first_profit_margin
    the_fee + 0.50
  end

  def later_profit_margin
    0.75
  end

  def the_fee
    (@current_price * 0.006) * 2 #double the fee because it happens during both and sell
  end

  def log_current_stats(i)
    @dc.prepend 'position_logs', "<br />loop #{i} ------------------- current time: #{Time.now} ---------__________________________________________________#{i == 1 ? "<br />" : "<br /><br /><br /><br /><br />" }"
    @dc.prepend 'position_logs', "current price: #{@current_price} <br />"
    @dc.prepend 'position_logs', "buy in price: #{@buy_in} <br />"
    @dc.prepend 'position_logs', "current base:  #{@base_level} <br />"
    @dc.prepend 'position_logs', "next base: #{distance_to_next_base} <br />"
    @dc.prepend 'position_logs', "stop level: #{@stop_level} <br />"
    @dc.prepend 'position_logs', "distance to stop: #{@current_price - @stop_level} <br />"
    @dc.prepend 'position_logs', "est total fee buy & sell: #{the_fee} <br /> "
    @dc.prepend 'position_logs', "position held: #{(Time.now - @complete_trade.created_at)/60} minutes <br />"
    @dc.prepend 'position_logs', "STATS <br />"
  end

  def set_and_log_indicator_ivars
    @day_20     = PriceEntry.day_20.average(:price).to_f
    @day_5      = PriceEntry.day_5.average(:price).to_f
    @day_1      = PriceEntry.day_1.average(:price).to_f
    @hour_12    = PriceEntry.hour_12.average(:price).to_f
    @hour_6     = PriceEntry.hour_6.average(:price).to_f
    @hour_2     = PriceEntry.hour_2.average(:price).to_f
    @hour_1     = PriceEntry.hour_1.average(:price).to_f
    @minutes_30 = PriceEntry.minutes_30.average(:price).to_f
    @minutes_10 = PriceEntry.minutes_10.average(:price).to_f

    #for leading indicators
    stoch_set = PriceEntry.minutes_20.in_groups(2, false)
    @stoch_2  = compute_stochastic stoch_set[0]
    @stoch_1  = compute_stochastic stoch_set[1]

    @dc.prepend 'position_logs', "stoch2: #{@stoch_2} <br /><br />"
    @dc.prepend 'position_logs', "stoch1 (latest): #{@stoch_1} <br />"
    @dc.prepend 'position_logs', "stoch data (2, 1): <br /> #{@stoch_data.present? ? @stoch_data : "N/A" } <br />"
    @dc.prepend 'position_logs', "LEADING INDICATORS <br />"

    @dc.prepend 'position_logs', "2 hour: #{@hour_2} <br /><br />"
    @dc.prepend 'position_logs', "1 hour: #{@hour_1} #{one_hour_beats_two_hour ? "green" : "red" } <br />"
    @dc.prepend 'position_logs', "30 min: #{@minutes_30} #{thirty_min_beats_one_hour ? "green" : "red" } <br />"
    @dc.prepend 'position_logs', "10 min: #{@minutes_10} #{ten_min_beats_thirty_min ? "green" : "red" } <br />"
    @dc.prepend 'position_logs', "LAGGING INDICATORS <br />"

    @stoch_data = []
  end

end


#TODO
#streaming websocket vs http ?
#still hardcoding the amount you're buying in at (0.01... change this)
#handling the appropriate fee
#handle case where buys and breaks... don't want to restart and buy in again.
#whenever/cron process to clear out price data that's older than 10 days (8640 entries per day). For free dev postgres, shoudl clear out every day.
#arbitrage features - do a separate bot...

