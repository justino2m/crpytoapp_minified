class CreateFingerprints < ActiveRecord::Migration[5.2]
  def change
    create_table :fingerprints do |t|
      t.references :user, foreign_key: true, null: false
      t.string :fp_type, null: false
      t.string :fp, null: false
      t.boolean :ignore, null: false, default: false
      t.jsonb :metadata

      t.timestamps
    end

    add_index :fingerprints, [:user_id, :fp_type, :fp], unique: true
  end
end
