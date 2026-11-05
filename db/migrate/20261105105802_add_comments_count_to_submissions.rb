class AddCommentsCountToSubmissions < ActiveRecord::Migration[8.1]
  def change
    add_column :submissions, :comments_count, :integer, default: 0, null: false
  end
end
