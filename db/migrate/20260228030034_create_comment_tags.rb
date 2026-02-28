class CreateCommentTags < ActiveRecord::Migration[8.0]
  def change
    create_table :comment_tags do |t|
      t.references :comment, null: false, foreign_key: true
      t.references :tag, null: false, foreign_key: true

      t.timestamps
    end
    
    add_index :comment_tags, [:comment_id, :tag_id], unique: true
  end
end
