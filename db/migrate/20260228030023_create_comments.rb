class CreateComments < ActiveRecord::Migration[8.0]
  def change
    create_table :comments do |t|
      t.bigint :github_id, null: false
      t.references :pull_request, null: false, foreign_key: true
      t.text :body, null: false
      t.string :author_name
      t.string :author_avatar
      t.string :author_role
      t.string :comment_type
      t.string :path
      t.integer :position
      t.integer :line
      t.boolean :ai_analyzed, default: false
      t.text :ai_summary
      t.datetime :github_created_at
      t.datetime :github_updated_at

      t.timestamps
    end
    
    add_index :comments, :github_id, unique: true
    add_index :comments, :author_name
    add_index :comments, :ai_analyzed
  end
end
