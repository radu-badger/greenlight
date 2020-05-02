class AddProjectIdToUsers < ActiveRecord::Migration[5.2]
  def change
    add_column :users, :reduct_project_id, :string
  end
end
