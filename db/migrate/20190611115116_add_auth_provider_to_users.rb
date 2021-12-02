class AddAuthProviderToUsers < ActiveRecord::Migration[5.2]
  def change
    add_column :users, :auth_provider, :string
    add_column :users, :auth_provider_id, :string
  end
end
