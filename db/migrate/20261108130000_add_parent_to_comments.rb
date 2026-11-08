class AddParentToComments < ActiveRecord::Migration[8.1]
  # COM-02: comments form a tree. A reply points to its parent comment
  # (self-referential), so parent_id is nullable (top-level comments have none).
  def change
    add_reference :comments, :parent, null: true,
      foreign_key: { to_table: :comments }
  end
end
