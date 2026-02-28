class CreateAiInsights < ActiveRecord::Migration[8.0]
  def change
    create_table :ai_insights do |t|
      t.string :insight_type
      t.string :title, null: false
      t.text :content, null: false
      t.jsonb :related_comments, default: []
      t.float :confidence_score
      t.string :ai_model

      t.timestamps
    end

    add_index :ai_insights, :insight_type
    add_index :ai_insights, :created_at
  end
end
