#this has shown to be unreliable, need to start own heroku worker instead (and pay the monthly price)

namespace :heroku do
  task :prices do
    `heroku run:detached rails runner "PriceEntry.fetch_price"`
  end

  task :positions do
    `heroku run:detached rails runner "BuySell.new.buy_in_loop"`
  end
end