class MoveUserFieldsIntoPreferences < ActiveRecord::Migration[5.2]
  def change
    remove_column :users, :realize_gains_on_fees
    remove_column :users, :account_based_cost_basis
    rename_column :users, :realize_gains_on_exchange, :old_realize_gains_on_exchange

    users = []
    ActiveRecord::Base.connection.execute('select id, preferences, old_realize_gains_on_exchange from users').to_a.each do |u|
      # need to decode it twice!
      next if u['preferences'].nil?
      users << { id: u['id'], preferences: JSON.parse(JSON.parse(u['preferences'])).merge('realize_gains_on_exchange' => u['old_realize_gains_on_exchange']) }
    rescue =>e
      Rollbar.warning("failed to migrate to user prefs due to error #{e.message}", u)
      raise
    end

    # this is needed due to null: false
    users.each { |u| u.merge!(name: '', email: '', base_currency_id: 1, display_currency_id: 1, last_seen_at: Time.now, created_at: Time.now, cost_basis_method: '', old_realize_gains_on_exchange: false) }
    User.import(users, on_duplicate_key_update: [:preferences], validate: false)

    remove_column :users, :old_realize_gains_on_exchange
  end
end
