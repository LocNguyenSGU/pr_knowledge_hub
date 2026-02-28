class Comment < ApplicationRecord
  belongs_to :pull_request
  has_many :comment_tags, dependent: :destroy
  has_many :tags, through: :comment_tags

  # Validations
  validates :github_id, presence: true, uniqueness: true
  validates :body, presence: true

  # Scopes
  scope :by_reviewers, -> { where.not(author_role: "author") }
  scope :unanalyzed, -> { where(ai_analyzed: false) }
  scope :analyzed, -> { where(ai_analyzed: true) }

  # Search - will be configured with pg_search
  include PgSearch::Model
  pg_search_scope :search_content,
    against: [ :body, :author_name ],
    using: {
      tsearch: { prefix: true }
    }

  # Helper method for cleaner API
  def analyzed?
    ai_analyzed
  end
end
