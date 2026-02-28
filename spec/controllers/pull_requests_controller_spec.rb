require 'rails_helper'

RSpec.describe PullRequestsController, type: :controller do
  describe "GET #index" do
    let!(:open_pr) { create(:pull_request, state: 'open', number: 1, github_created_at: 2.days.ago) }
    let!(:merged_pr) { create(:pull_request, state: 'merged', number: 2, author_name: 'John', github_created_at: 1.day.ago) }
    let!(:closed_pr) { create(:pull_request, state: 'closed', number: 3, author_name: 'Jane', github_created_at: 3.days.ago) }

    before { get :index }

    it "assigns all pull requests to @pull_requests" do
      expect(assigns(:pull_requests)).to match_array([ open_pr, merged_pr, closed_pr ])
    end

    it "assigns available states to @states" do
      expect(assigns(:states)).to match_array([ 'open', 'merged', 'closed' ])
    end

    it "assigns authors to @authors" do
      expect(assigns(:authors)).to include('John', 'Jane')
    end

    it "returns http success" do
      expect(response).to have_http_status(:success)
    end

    it "renders the index template" do
      expect(response).to render_template(:index)
    end

    context "with state filter" do
      before { get :index, params: { state: 'open' } }

      it "filters by state" do
        expect(assigns(:pull_requests)).to eq([ open_pr ])
      end
    end

    context "with author filter" do
      before { get :index, params: { author: 'John' } }

      it "filters by author" do
        expect(assigns(:pull_requests)).to eq([ merged_pr ])
      end
    end

    context "with sorting" do
      it "sorts by number ascending" do
        get :index, params: { sort: 'number', direction: 'asc' }
        expect(assigns(:pull_requests).map(&:number)).to eq([ 1, 2, 3 ])
      end

      it "sorts by created_at descending by default" do
        expect(assigns(:pull_requests).first).to eq(merged_pr) # most recent
      end

      it "ignores invalid sort column" do
        get :index, params: { sort: 'invalid_column' }
        expect(response).to have_http_status(:success)
      end
    end

    context "with pagination" do
      before do
        create_list(:pull_request, 25, state: 'open')
        get :index, params: { page: 1 }
      end

      it "paginates results" do
        expect(assigns(:pull_requests).size).to eq(20)
      end
    end

    context "with combined filters" do
      before { get :index, params: { state: 'merged', author: 'John' } }

      it "applies multiple filters" do
        expect(assigns(:pull_requests)).to eq([ merged_pr ])
      end
    end
  end

  describe "GET #show" do
    let!(:pull_request) { create(:pull_request) }
    let!(:comment1) { create(:comment, pull_request: pull_request, author_role: 'reviewer', ai_analyzed: true, github_created_at: 2.days.ago) }
    let!(:comment2) { create(:comment, pull_request: pull_request, author_role: 'author', ai_analyzed: false, github_created_at: 1.day.ago) }
    let!(:tag) { create(:tag) }
    let!(:comment_tag) { create(:comment_tag, comment: comment1, tag: tag) }

    before { get :show, params: { id: pull_request.id } }

    it "assigns the requested pull request to @pull_request" do
      expect(assigns(:pull_request)).to eq(pull_request)
    end

    it "assigns comments ordered by github_created_at" do
      expect(assigns(:comments)).to eq([ comment1, comment2 ])
    end

    it "includes tags in comments" do
      expect(assigns(:comments).first.tags).to include(tag)
    end

    it "calculates comment stats" do
      stats = assigns(:comment_stats)
      expect(stats[:total]).to eq(2)
      expect(stats[:by_reviewers]).to eq(1)
      expect(stats[:analyzed]).to eq(1)
      expect(stats[:tagged]).to eq(1)
    end

    it "returns http success" do
      expect(response).to have_http_status(:success)
    end

    it "renders the show template" do
      expect(response).to render_template(:show)
    end

    context "with no comments" do
      before do
        pull_request.comments.destroy_all
        get :show, params: { id: pull_request.id }
      end

      it "handles empty comments gracefully" do
        expect(assigns(:comments)).to be_empty
        expect(assigns(:comment_stats)[:total]).to eq(0)
      end
    end

    context "with related insights" do
      let!(:insight) { create(:ai_insight, related_comments: [ comment1.id.to_s ]) }

      before { get :show, params: { id: pull_request.id } }

      it "assigns related insights" do
        expect(assigns(:related_insights)).to include(insight)
      end
    end

    context "when pull request not found" do
      it "raises RecordNotFound" do
        expect {
          get :show, params: { id: 99999 }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe "GET #stats" do
    before do
      create(:pull_request, state: 'open', author_name: 'Alice', additions: 100, deletions: 50)
      create(:pull_request, state: 'merged', author_name: 'Alice', additions: 200, deletions: 100)
      create(:pull_request, state: 'closed', author_name: 'Bob', additions: 150, deletions: 75)
    end

    before { get :stats, format: :json }

    it "returns JSON response" do
      expect(response.content_type).to include('application/json')
    end

    it "returns http success" do
      expect(response).to have_http_status(:success)
    end

    it "includes PRs grouped by state" do
      json = JSON.parse(response.body)
      expect(json['by_state']).to be_a(Hash)
      expect(json['by_state']['open']).to eq(1)
      expect(json['by_state']['merged']).to eq(1)
      expect(json['by_state']['closed']).to eq(1)
    end

    it "includes PRs grouped by author" do
      json = JSON.parse(response.body)
      expect(json['by_author']).to be_a(Hash)
      expect(json['by_author']['Alice']).to eq(2)
      expect(json['by_author']['Bob']).to eq(1)
    end

    it "includes average additions and deletions" do
      json = JSON.parse(response.body)
      expect(json['avg_additions']).to eq(150) # (100+200+150)/3
      expect(json['avg_deletions']).to eq(75)  # (50+100+75)/3
    end

    it "limits authors to top 10" do
      create_list(:pull_request, 15, state: 'open').each_with_index do |pr, i|
        pr.update(author_name: "Author#{i}")
      end

      get :stats, format: :json
      json = JSON.parse(response.body)
      expect(json['by_author'].size).to be <= 10
    end
  end
end
