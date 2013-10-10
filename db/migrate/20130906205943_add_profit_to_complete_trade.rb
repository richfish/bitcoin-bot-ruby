class AddProfitToCompleteTrade < ActiveRecord::Migration
  def change
    add_column :complete_trades, :profit, :decimal
  end
end
