require 'rails_helper'

RSpec.describe PullRequest, type: :model do
  describe 'associations' do
    it { should have_many(:comments).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:github_id) }
    it { should validate_presence_of(:number) }
    it { should validate_presence_of(:title) }

    it 'validates uniqueness of github_id' do
      create(:pull_request)
      should validate_uniqueness_of(:github_id)
    end
  end

  describe 'scopes' do
    let!(:open_pr) { create(:pull_request, state: 'open') }
    let!(:closed_pr) { create(:pull_request, :closed) }
    let!(:merged_pr) { create(:pull_request, :merged) }

    describe '.open_prs' do
      it 'returns only open PRs' do
        expect(PullRequest.open_prs).to include(open_pr)
        expect(PullRequest.open_prs).not_to include(closed_pr)
        expect(PullRequest.open_prs).not_to include(merged_pr)
      end
    end

    describe '.closed_prs' do
      it 'returns closed and merged PRs' do
        expect(PullRequest.closed_prs).to include(closed_pr)
        expect(PullRequest.closed_prs).to include(merged_pr)
        expect(PullRequest.closed_prs).not_to include(open_pr)
      end
    end
  end
end
