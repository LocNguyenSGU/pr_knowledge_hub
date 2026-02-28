class PullRequest < ApplicationRecord
  has_many :comments, dependent: :destroy

  # Validations
  validates :github_id, presence: true, uniqueness: true
  validates :number, presence: true
  validates :title, presence: true
  validates :repository_url, format: { with: %r{\Ahttps://github\.com/.*\z}, message: "must be a valid GitHub URL" }, allow_blank: true

  # Scopes
  scope :open, -> { where(state: "open") }
  scope :closed, -> { where(state: "closed") }
  scope :merged, -> { where(state: "merged") }
  scope :recent, -> { order(github_created_at: :desc) }

  # Scope aliases for test compatibility
  scope :open_prs, -> { open }
  scope :closed_prs, -> { where(state: %w[closed merged]) }

  # Helper methods
  def reviewer_comments
    comments.where.not(author_role: "author")
  end

  def merged?
    state == "merged" && merged_at.present?
  end
end
