class AddPointsToComments < ActiveRecord::Migration[8.1]
  # ACT-04: comments gain a vote score, like submissions.
  def change
    add_column :comments, :points, :integer, default: 0, null: false
  end
end
