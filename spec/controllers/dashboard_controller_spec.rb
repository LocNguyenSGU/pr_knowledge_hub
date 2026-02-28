require 'rails_helper'

RSpec.describe DashboardController, type: :controller do
  describe "GET #index" do
    let!(:open_pr) { create(:pull_request, state: 'open') }
    let!(:merged_pr) { create(:pull_request, state: 'merged') }
    let!(:analyzed_comment) { create(:comment, pull_request: open_pr, ai_analyzed: true) }
    let!(:unanalyzed_comment) { create(:comment, pull_request: merged_pr, ai_analyzed: false) }
    let!(:insight) { create(:ai_insight) }
    let!(:tag) { create(:tag) }
    let!(:comment_tag) { create(:comment_tag, comment: analyzed_comment, tag: tag) }

    before { get :index }

    it "assigns @stats with dashboard statistics" do
      expect(assigns(:stats)).to be_a(Hash)
      expect(assigns(:stats)[:total_prs]).to eq(2)
      expect(assigns(:stats)[:open_prs]).to eq(1)
      expect(assigns(:stats)[:merged_prs]).to eq(1)
      expect(assigns(:stats)[:total_comments]).to eq(2)
      expect(assigns(:stats)[:analyzed_comments]).to eq(1)
      expect(assigns(:stats)[:total_insights]).to eq(1)
      expect(assigns(:stats)[:avg_comments_per_pr]).to eq(1.0)
    end

    it "assigns @recent_prs with 10 most recent pull requests" do
      expect(assigns(:recent_prs)).to include(open_pr, merged_pr)
      expect(assigns(:recent_prs).size).to be <= 10
    end

    it "assigns @recent_insights with 5 most recent insights" do
      expect(assigns(:recent_insights)).to include(insight)
      expect(assigns(:recent_insights).size).to be <= 5
    end

    it "assigns @top_tags with tags ordered by comment count" do
      expect(assigns(:top_tags)).to include(tag)
      expect(assigns(:top_tags).size).to be <= 10
    end

    it "returns http success" do
      expect(response).to have_http_status(:success)
    end

    it "renders the index template" do
      expect(response).to render_template(:index)
    end

    context "with many pull requests" do
      before do
        create_list(:pull_request, 15, state: 'open')
        get :index
      end

      it "limits recent PRs to 10" do
        expect(assigns(:recent_prs).size).to eq(10)
      end
    end

    context "with many insights" do
      before do
        create_list(:ai_insight, 10)
        get :index
      end

      it "limits recent insights to 5" do
        expect(assigns(:recent_insights).size).to eq(5)
      end
    end

    context "with no data" do
      before do
        PullRequest.destroy_all
        Comment.destroy_all
        AiInsight.destroy_all
        Tag.destroy_all
        get :index
      end

      it "handles empty database gracefully" do
        expect(assigns(:stats)[:total_prs]).to eq(0)
        expect(assigns(:stats)[:avg_comments_per_pr]).to eq(0.0)
        expect(assigns(:recent_prs)).to be_empty
        expect(assigns(:recent_insights)).to be_empty
        expect(assigns(:top_tags)).to be_empty
      end
    end
  end
end
