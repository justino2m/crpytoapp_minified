class CreateReports < ActiveRecord::Migration[5.2]
  def change
    create_table :reports do |t|
      t.references :user, foreign_key: true, null: false
      t.string :type, null: false
      t.string :name, null: false
      t.datetime :from
      t.datetime :to
      t.datetime :generated_at
      t.jsonb :options

      t.timestamps
    end
  end
end
