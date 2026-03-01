class AiInsight < ApplicationRecord
  # Validations
  validates :title, presence: true
  validates :content, presence: true
  validates :insight_type, presence: true, inclusion: { in: %w[pattern lesson recommendation] }

  # Scopes
  scope :patterns, -> { where(insight_type: "pattern") }
  scope :lessons, -> { where(insight_type: "lesson") }
  scope :recommendations, -> { where(insight_type: "recommendation") }
  scope :recent, -> { order(created_at: :desc) }

  # Helper methods
  def metadata
    {
      "related_comment_ids" => related_comments || [],
      "tag" => nil
    }
  end

  def related_comment_objects
    return [] if related_comments.blank?
    Comment.where(id: related_comments)
  end
end
