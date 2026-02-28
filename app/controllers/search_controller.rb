class SearchController < ApplicationController
  def index
    @query = params[:q]
    @scope = params[:scope] || "comments"

    if @query.present?
      case @scope
      when "comments"
        search_comments
      when "pull_requests"
        search_pull_requests
      when "insights"
        search_insights
      else
        @results = []
      end
    else
      @results = []
    end

    @result_count = @results.is_a?(ActiveRecord::Relation) ? @results.count : @results.size
  end

  private

  def search_comments
    @results = Comment.where("body ILIKE ?", "%#{@query}%")
                     .includes(:pull_request, :tags)
                     .order(github_created_at: :desc)
                     .page(params[:page]).per(20)
  end

  def search_pull_requests
    @results = PullRequest.where("title ILIKE ? OR body ILIKE ?", "%#{@query}%", "%#{@query}%")
                         .order(github_created_at: :desc)
                         .page(params[:page]).per(20)
  end

  def search_insights
    @results = AiInsight.where("title ILIKE ? OR content ILIKE ?", "%#{@query}%", "%#{@query}%")
                       .order(created_at: :desc)
                       .page(params[:page]).per(20)
  end
end
