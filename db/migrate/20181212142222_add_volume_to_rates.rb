class AddVolumeToRates < ActiveRecord::Migration[5.2]
  def change
    add_column :rates, :volume, :decimal, null: false, default: 0
  end
end
