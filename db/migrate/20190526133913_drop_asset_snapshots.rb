class DropAssetSnapshots < ActiveRecord::Migration[5.2]
  def change
    drop_table :asset_snapshots
  end
end
