require 'rails_helper'

RSpec.describe CommentTag, type: :model do
  describe 'associations' do
    it { should belong_to(:comment) }
    it { should belong_to(:tag) }
  end

  describe 'validations' do
    let(:comment) { create(:comment) }
    let(:tag) { create(:tag) }

    it 'validates uniqueness of comment and tag combination' do
      CommentTag.create!(comment: comment, tag: tag)
      duplicate = CommentTag.new(comment: comment, tag: tag)
      expect(duplicate).not_to be_valid
    end
  end
end
