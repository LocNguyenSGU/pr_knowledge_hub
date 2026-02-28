class CreatePullRequests < ActiveRecord::Migration[8.0]
  def change
    create_table :pull_requests do |t|
      t.bigint :github_id, null: false
      t.integer :number, null: false
      t.string :title, null: false
      t.text :body
      t.string :state
      t.string :author_name
      t.string :author_avatar
      t.string :repository_name
      t.string :repository_url
      t.integer :additions, default: 0
      t.integer :deletions, default: 0
      t.integer :changed_files_count, default: 0
      t.string :mergeable_state
      t.boolean :draft, default: false
      t.datetime :github_created_at
      t.datetime :github_updated_at
      t.datetime :closed_at
      t.datetime :merged_at
      t.datetime :last_synced_at

      t.timestamps
    end

    add_index :pull_requests, :github_id, unique: true
    add_index :pull_requests, :state
    add_index :pull_requests, :github_created_at
  end
end
