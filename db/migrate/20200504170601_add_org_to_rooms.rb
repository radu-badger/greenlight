class AddOrgToRooms < ActiveRecord::Migration[5.2]
  def change
    add_column :rooms, :org, :string
  end
end
