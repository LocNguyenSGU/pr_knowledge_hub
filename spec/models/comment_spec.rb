require 'rails_helper'

RSpec.describe Comment, type: :model do
  describe 'associations' do
    it { should belong_to(:pull_request) }
    it { should have_many(:comment_tags).dependent(:destroy) }
    it { should have_many(:tags).through(:comment_tags) }
  end

  describe 'validations' do
    it { should validate_presence_of(:github_id) }
    it { should validate_presence_of(:body) }

    it 'validates uniqueness of github_id' do
      create(:comment)
      should validate_uniqueness_of(:github_id)
    end
  end

  describe 'scopes' do
    let!(:author_comment) { create(:comment, author_role: 'author') }
    let!(:reviewer_comment) { create(:comment, author_role: 'reviewer') }
    let!(:unanalyzed) { create(:comment, ai_analyzed: false) }
    let!(:analyzed) { create(:comment, ai_analyzed: true) }

    describe '.by_reviewers' do
      it 'excludes author comments' do
        expect(Comment.by_reviewers).to include(reviewer_comment)
        expect(Comment.by_reviewers).not_to include(author_comment)
      end
    end

    describe '.unanalyzed' do
      it 'returns only unanalyzed comments' do
        expect(Comment.unanalyzed).to include(unanalyzed)
        expect(Comment.unanalyzed).not_to include(analyzed)
      end
    end

    describe '.analyzed' do
      it 'returns only analyzed comments' do
        expect(Comment.analyzed).to include(analyzed)
        expect(Comment.analyzed).not_to include(unanalyzed)
      end
    end
  end
end
