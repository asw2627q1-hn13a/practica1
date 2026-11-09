class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :provider
      t.string :uid
      t.string :username
      t.string :email
      t.text :about

      t.timestamps
    end
    
    add_index :users, [:provider, :uid], unique: true
  end
end
