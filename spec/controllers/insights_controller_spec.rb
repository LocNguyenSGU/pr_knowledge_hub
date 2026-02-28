require 'rails_helper'

RSpec.describe InsightsController, type: :controller do
  describe "GET #index" do
    let!(:pattern) { create(:ai_insight, insight_type: 'pattern', created_at: 2.days.ago) }
    let!(:lesson) { create(:ai_insight, insight_type: 'lesson', created_at: 1.day.ago) }
    let!(:recommendation) { create(:ai_insight, insight_type: 'recommendation', created_at: 3.days.ago) }

    before { get :index }

    it "assigns insights ordered by created_at desc" do
      expect(assigns(:insights)).to eq([ lesson, pattern, recommendation ])
    end

    it "assigns available insight types" do
      expect(assigns(:insight_types)).to match_array([ 'pattern', 'lesson', 'recommendation' ])
    end

    it "calculates insight stats" do
      stats = assigns(:stats)
      expect(stats[:total]).to eq(3)
      expect(stats[:patterns]).to eq(1)
      expect(stats[:lessons]).to eq(1)
      expect(stats[:recommendations]).to eq(1)
    end

    it "returns http success" do
      expect(response).to have_http_status(:success)
    end

    it "renders the index template" do
      expect(response).to render_template(:index)
    end

    context "with type filter" do
      it "filters by pattern type" do
        get :index, params: { type: 'pattern' }
        expect(assigns(:insights)).to eq([ pattern ])
      end

      it "filters by lesson type" do
        get :index, params: { type: 'lesson' }
        expect(assigns(:insights)).to eq([ lesson ])
      end

      it "filters by recommendation type" do
        get :index, params: { type: 'recommendation' }
        expect(assigns(:insights)).to eq([ recommendation ])
      end

      it "ignores invalid type" do
        get :index, params: { type: 'invalid_type' }
        expect(assigns(:insights)).to match_array([ lesson, pattern, recommendation ])
      end
    end

    context "with pagination" do
      before do
        create_list(:ai_insight, 20, insight_type: 'pattern')
        get :index, params: { page: 1 }
      end

      it "paginates results to 15 per page" do
        expect(assigns(:insights).size).to eq(15)
      end

      it "has multiple pages" do
        expect(assigns(:insights).total_pages).to be > 1
      end
    end

    context "with no insights" do
      before do
        AiInsight.destroy_all
        get :index
      end

      it "handles empty database" do
        expect(assigns(:insights)).to be_empty
        expect(assigns(:stats)[:total]).to eq(0)
      end
    end
  end

  describe "GET #show" do
    let(:pull_request) { create(:pull_request) }
    let(:comment1) { create(:comment, pull_request: pull_request, github_created_at: 2.days.ago) }
    let(:comment2) { create(:comment, pull_request: pull_request, github_created_at: 1.day.ago) }
    let(:insight) { create(:ai_insight, related_comments: [ comment1.id, comment2.id ]) }
    let(:tag) { create(:tag) }
    let!(:comment_tag) { create(:comment_tag, comment: comment1, tag: tag) }

    before { get :show, params: { id: insight.id } }

    it "assigns the requested insight" do
      expect(assigns(:insight)).to eq(insight)
    end

    it "assigns related comments" do
      expect(assigns(:related_comments)).to match_array([ comment1, comment2 ])
    end

    it "orders related comments by github_created_at desc" do
      expect(assigns(:related_comments).first).to eq(comment2)
    end

    it "includes pull_request in related comments" do
      expect(assigns(:related_comments).first.pull_request).to eq(pull_request)
    end

    it "includes tags in related comments" do
      expect(assigns(:related_comments).last.tags).to include(tag)
    end

    it "returns http success" do
      expect(response).to have_http_status(:success)
    end

    it "renders the show template" do
      expect(response).to render_template(:show)
    end

    context "with no related comments" do
      let(:insight_without_comments) { create(:ai_insight, related_comments: nil) }

      before { get :show, params: { id: insight_without_comments.id } }

      it "handles nil related_comments" do
        expect(assigns(:related_comments)).to eq([])
      end
    end

    context "with empty related comments array" do
      let(:insight_with_empty_array) { create(:ai_insight, related_comments: []) }

      before { get :show, params: { id: insight_with_empty_array.id } }

      it "handles empty array" do
        expect(assigns(:related_comments)).to eq([])
      end
    end

    context "when insight not found" do
      it "raises RecordNotFound" do
        expect {
          get :show, params: { id: 99999 }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
