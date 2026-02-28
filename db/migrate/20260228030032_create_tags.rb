class CreateTags < ActiveRecord::Migration[8.0]
  def change
    create_table :tags do |t|
      t.string :name, null: false
      t.string :color, default: '#6B7280'
      t.text :description
      t.string :category

      t.timestamps
    end
    
    add_index :tags, :name, unique: true
  end
end
