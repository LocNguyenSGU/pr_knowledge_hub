require 'rails_helper'

RSpec.describe SearchController, type: :controller do
  describe "GET #index" do
    it "returns http success" do
      get :index, params: { q: 'security' }
      expect(response).to have_http_status(:success)
    end

    it "renders the index template" do
      get :index, params: { q: 'security' }
      expect(response).to render_template(:index)
    end

    context "with no query" do
      before { get :index }

      it "assigns empty results" do
        expect(assigns(:results)).to eq([])
      end

      it "sets result_count to 0" do
        expect(assigns(:result_count)).to eq(0)
      end
    end

    context "with query and no scope" do
      let(:pr) { create(:pull_request) }
      let!(:comment1) { create(:comment, pull_request: pr, body: 'This is a great security fix') }
      let!(:comment2) { create(:comment, pull_request: pr, body: 'Please add more tests') }

      before { get :index, params: { q: 'security' } }

      it "defaults to comments scope" do
        expect(assigns(:scope)).to eq('comments')
      end

      it "searches comments" do
        expect(assigns(:results)).to include(comment1)
        expect(assigns(:results)).not_to include(comment2)
      end
    end

    context "searching comments" do
      let(:pr) { create(:pull_request) }
      let!(:comment1) { create(:comment, pull_request: pr, body: 'This is a great security fix') }
      let!(:comment2) { create(:comment, pull_request: pr, body: 'Please add more tests') }
      before { get :index, params: { q: 'security', scope: 'comments' } }

      it "assigns matching comments" do
        expect(assigns(:results)).to include(comment1)
      end

      it "excludes non-matching comments" do
        expect(assigns(:results)).not_to include(comment2)
      end

      it "includes pull_request association" do
        expect(assigns(:results).first.association(:pull_request)).to be_loaded
      end

      it "includes tags association" do
        tag = create(:tag)
        create(:comment_tag, comment: comment1, tag: tag)
        get :index, params: { q: 'security', scope: 'comments' }
        expect(assigns(:results).first.association(:tags)).to be_loaded
      end

      it "orders by github_created_at desc" do
        older_comment = create(:comment, body: 'Old security comment', github_created_at: 3.days.ago)
        newer_comment = create(:comment, body: 'New security comment', github_created_at: 1.day.ago)
        get :index, params: { q: 'security', scope: 'comments' }
        expect(assigns(:results).first).to eq(newer_comment)
      end

      it "performs case-insensitive search" do
        get :index, params: { q: 'SECURITY', scope: 'comments' }
        expect(assigns(:results)).to include(comment1)
      end

      it "sets correct result_count" do
        expect(assigns(:result_count)).to eq(1)
      end

      context "with pagination" do
        before do
          create_list(:comment, 25, body: 'security test')
          get :index, params: { q: 'security', scope: 'comments', page: 1 }
        end

        it "paginates results to 20 per page" do
          expect(assigns(:results).size).to eq(20)
        end
      end
    end

    context "searching pull requests" do
      let!(:pr_title_match) { create(:pull_request, title: 'Add security header', body: 'Add CORS') }
      let!(:pr_body_match) { create(:pull_request, title: 'Update deps', body: 'Fix security vulnerability') }
      let!(:pr_no_match) { create(:pull_request, title: 'Refactor code', body: 'Clean up') }

      before { get :index, params: { q: 'security', scope: 'pull_requests' } }

      it "assigns matching pull requests by title" do
        expect(assigns(:results)).to include(pr_title_match)
      end

      it "assigns matching pull requests by body" do
        expect(assigns(:results)).to include(pr_body_match)
      end

      it "excludes non-matching pull requests" do
        expect(assigns(:results)).not_to include(pr_no_match)
      end

      it "orders by github_created_at desc" do
        older_pr = create(:pull_request, title: 'Old security', github_created_at: 3.days.ago)
        newer_pr = create(:pull_request, title: 'New security', github_created_at: 1.day.ago)
        get :index, params: { q: 'security', scope: 'pull_requests' }
        results = assigns(:results)
        expect(results.to_a.index(newer_pr)).to be < results.to_a.index(older_pr)
      end

      it "performs case-insensitive search" do
        get :index, params: { q: 'SECURITY', scope: 'pull_requests' }
        expect(assigns(:results)).to include(pr_title_match)
      end

      it "sets correct result_count" do
        expect(assigns(:result_count)).to eq(2)
      end

      context "with pagination" do
        before do
          create_list(:pull_request, 25, title: 'security fix')
          get :index, params: { q: 'security', scope: 'pull_requests', page: 1 }
        end

        it "paginates results to 20 per page" do
          expect(assigns(:results).size).to eq(20)
        end
      end
    end

    context "searching insights" do
      let!(:insight_title_match) { create(:ai_insight, title: 'Security Best Practice', content: 'Use strong passwords') }
      let!(:insight_content_match) { create(:ai_insight, title: 'Code Review', content: 'Check for security issues') }
      let!(:insight_no_match) { create(:ai_insight, title: 'Performance', content: 'Optimize queries') }

      before { get :index, params: { q: 'security', scope: 'insights' } }

      it "assigns matching insights by title" do
        expect(assigns(:results)).to include(insight_title_match)
      end

      it "assigns matching insights by content" do
        expect(assigns(:results)).to include(insight_content_match)
      end

      it "excludes non-matching insights" do
        expect(assigns(:results)).not_to include(insight_no_match)
      end

      it "orders by created_at desc" do
        older_insight = create(:ai_insight, title: 'Old security', created_at: 3.days.ago)
        newer_insight = create(:ai_insight, title: 'New security', created_at: 1.day.ago)
        get :index, params: { q: 'security', scope: 'insights' }
        results = assigns(:results)
        expect(results.to_a.index(newer_insight)).to be < results.to_a.index(older_insight)
      end

      it "performs case-insensitive search" do
        get :index, params: { q: 'SECURITY', scope: 'insights' }
        expect(assigns(:results)).to include(insight_title_match)
      end

      it "sets correct result_count" do
        expect(assigns(:result_count)).to eq(2)
      end

      context "with pagination" do
        before do
          create_list(:ai_insight, 25, title: 'security pattern')
          get :index, params: { q: 'security', scope: 'insights', page: 1 }
        end

        it "paginates results to 20 per page" do
          expect(assigns(:results).size).to eq(20)
        end
      end
    end

    context "with invalid scope" do
      before { get :index, params: { q: 'security', scope: 'invalid' } }

      it "assigns empty results" do
        expect(assigns(:results)).to eq([])
      end

      it "sets result_count to 0" do
        expect(assigns(:result_count)).to eq(0)
      end
    end

    context "with no results" do
      before { get :index, params: { q: 'nonexistent_query', scope: 'comments' } }

      it "assigns empty results" do
        expect(assigns(:results)).to be_empty
      end

      it "sets result_count to 0" do
        expect(assigns(:result_count)).to eq(0)
      end
    end

    context "with special characters in query" do
      it "handles special characters safely" do
        get :index, params: { q: "test's \"quoted\"", scope: 'comments' }
        expect(response).to have_http_status(:success)
      end

      it "handles SQL wildcards" do
        get :index, params: { q: "%_test", scope: 'comments' }
        expect(response).to have_http_status(:success)
      end
    end
  end
end
