class AddJiraCustomerIdToUsers < ActiveRecord::Migration[5.2]
  def change
    add_column :users, :jira_customer_id, :string
  end
end
