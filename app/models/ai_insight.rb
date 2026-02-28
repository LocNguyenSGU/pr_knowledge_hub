class AiInsight < ApplicationRecord
  # Validations
  validates :title, presence: true
  validates :content, presence: true
  
  # Scopes
  scope :patterns, -> { where(insight_type: 'pattern') }
  scope :lessons, -> { where(insight_type: 'lesson') }
  scope :recommendations, -> { where(insight_type: 'recommendation') }
  scope :recent, -> { order(created_at: :desc) }
  
  # Helper methods
  def related_comment_objects
    return [] if related_comments.blank?
    Comment.where(id: related_comments)
  end
end
