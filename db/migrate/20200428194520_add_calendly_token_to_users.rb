class AddCalendlyTokenToUsers < ActiveRecord::Migration[5.2]
  def change
    add_column :users, :calendly_token, :string
  end
end
