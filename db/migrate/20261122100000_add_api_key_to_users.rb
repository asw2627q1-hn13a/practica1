class AddApiKeyToUsers < ActiveRecord::Migration[8.1]
  # Minimal model, decoupled from app/models/User, so the backfill keeps working
  # even if the real model changes later (validations, associations, renamed
  # columns). update_columns also skips validations and callbacks.
  class MigrationUser < ActiveRecord::Base
    self.table_name = "users"
  end

  # API-01: every user gets a unique, hard-to-guess api-key to call the API.
  def up
    add_column :users, :api_key, :string

    # Backfill existing users (seeds / production) so none is left without a key
    # before we add the NOT NULL + unique constraints.
    MigrationUser.reset_column_information
    MigrationUser.where(api_key: nil).find_each do |user|
      user.update_columns(api_key: SecureRandom.base58(24))
    end

    change_column_null :users, :api_key, false
    add_index :users, :api_key, unique: true
  end

  def down
    remove_index :users, :api_key
    remove_column :users, :api_key
  end
end
