class AddBuyIdToCompleteTrade < ActiveRecord::Migration
  def change
    add_column :complete_trades, :buy_id, :string
    add_column :complete_trades, :sell_id, :string
  end
end
