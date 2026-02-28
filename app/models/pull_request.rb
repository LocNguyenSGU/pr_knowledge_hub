class PullRequest < ApplicationRecord
  has_many :comments, dependent: :destroy
  
  # Validations
  validates :github_id, presence: true, uniqueness: true
  validates :number, presence: true
  validates :title, presence: true
  
  # Scopes
  scope :open, -> { where(state: 'open') }
  scope :closed, -> { where(state: 'closed') }
  scope :merged, -> { where(state: 'merged') }
  scope :recent, -> { order(github_created_at: :desc) }
  
  # Helper methods
  def reviewer_comments
    comments.where.not(author_role: 'author')
  end
  
  def merged?
    state == 'merged' && merged_at.present?
  end
end
