class CreatePriceEntries < ActiveRecord::Migration
  def change
    create_table :price_entries do |t|
      t.decimal :price

      t.timestamps
    end
  end
end
