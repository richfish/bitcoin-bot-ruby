task :buy_sell => :environment do
  BuySell.new.delay.buy_in_loop
end