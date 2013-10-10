class CreateCompleteTrades < ActiveRecord::Migration
  def change
    create_table :complete_trades do |t|
      t.decimal :buy
      t.decimal :sell

      t.timestamps
    end
  end
end
