class PriceEntry < ActiveRecord::Base
  scope :day_20, -> { where("created_at > ?", Time.now - 20.days) }
  scope :day_5, -> { where("created_at > ?", Time.now - 5.days) }
  scope :day_1, -> { where("created_at > ?", Time.now - 1.day) }
  scope :hour_12, -> { where("created_at > ?", Time.now - 12.hours) }
  scope :hour_6, -> { where("created_at > ?", Time.now - 6.hours) }
  scope :hour_2, -> { where("created_at > ?", Time.now - 2.hours) }
  scope :hour_1, -> { where("created_at > ?", Time.now - 1.hour) }
  scope :minutes_30, -> { where("created_at > ?", Time.now - 30.minutes) }
  scope :minutes_10, -> { where("created_at > ?", Time.now - 10.minutes) }
  scope :minutes_20, -> { where("created_at > ?", Time.now - 20.minutes) }

  def self.time_between(num)
    arr = PriceEntry.all[num..-1]
    arr2 = arr.each_with_index.map{ |pr, i| (pr.created_at - arr[i+1].created_at).abs unless arr[i+1].nil? }.compact
  end

  def self.fetch_price
    # file = Rails.env == "development" ? "#{Rails.root}/log/priceentry_dev.log" : "#{Rails.root}/lib/priceentry_prod.txt"
    # f = File.open(file, "w")
    #price_logger = Logger.new file

    @dc = Dalli::Client.new
    @dc.add 'price_logs', "start of logs", nil, { raw: true }

    loop do
      price = MtGox.ticker.sell.to_f
      PriceEntry.create(price: price)
      write_to_cache price
      sleep 10
    end
  end

  protected

  def self.write_to_cache(price)
    @dc.prepend 'price_logs', "<br /> <br /> ------------------- added price: #{price} -----------------"
  end

  # def self.write_to_log(price)
  #     file = Rails.env == "development" ? "#{Rails.root}/log/priceentry_dev.log" : "#{Rails.root}/lib/priceentry_prod.txt"
  #     File.open(file, "a") do |f|
  #       f.puts "\n\n ------------ added price: #{price} -----------------"
  #     end
  #   end


end
