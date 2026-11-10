class CreateHides < ActiveRecord::Migration[8.1]
  # ACT-06: a user can hide a submission (once) from their own listings.
  def change
    create_table :hides do |t|
      t.references :user, null: false, foreign_key: true
      t.references :submission, null: false, foreign_key: true
      t.timestamps
    end
    add_index :hides, [ :user_id, :submission_id ], unique: true
  end
end
