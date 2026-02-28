class Tag < ApplicationRecord
  has_many :comment_tags, dependent: :destroy
  has_many :comments, through: :comment_tags

  # Validations
  validates :name, presence: true, uniqueness: true

  # Constants
  CATEGORIES = %w[
    security
    performance
    code_style
    best_practice
    bug
    refactoring
    testing
    documentation
    question
  ].freeze

  validates :category, inclusion: { in: CATEGORIES }
end
