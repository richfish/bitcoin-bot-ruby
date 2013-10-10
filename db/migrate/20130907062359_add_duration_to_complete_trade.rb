class AddDurationToCompleteTrade < ActiveRecord::Migration
  def change
    add_column :complete_trades, :duration, :decimal
  end
end
