task :fetch_price => :environment do
  #not gunna work anyways. no rails environment
  PriceEntry.delay.fetch_price
end