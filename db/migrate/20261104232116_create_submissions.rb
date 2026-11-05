class CreateSubmissions < ActiveRecord::Migration[8.1]
  def change
    create_table :submissions do |t|
      t.string :title
      t.string :url
      t.text :text
      t.string :submission_type, default: "url", null: false
      t.integer :points, default: 0, null: false
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
