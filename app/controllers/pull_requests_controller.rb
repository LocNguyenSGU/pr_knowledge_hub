class PullRequestsController < ApplicationController
  def index
    @pull_requests = PullRequest.all
                                .then { |scope| filter_by_state(scope) }
                                .then { |scope| filter_by_author(scope) }
                                .order(sort_column => sort_direction)
                                .page(params[:page]).per(20)

    @states = PullRequest.distinct.pluck(:state).compact
    @authors = PullRequest.distinct.pluck(:author_name).compact.sort
  end

  def show
    @pull_request = PullRequest.find(params[:id])
    @comments = @pull_request.comments
                             .includes(:tags)
                             .order(github_created_at: :asc)

    @comment_stats = {
      total: @comments.count,
      by_reviewers: @comments.where.not(author_role: "author").count,
      analyzed: @comments.where(ai_analyzed: true).count,
      tagged: @comments.joins(:tags).distinct.count
    }

    @related_insights = find_related_insights
  end

  def stats
    @stats = {
      by_state: PullRequest.group(:state).count,
      by_author: PullRequest.group(:author_name).order("count_all DESC").limit(10).count,
      avg_additions: PullRequest.average(:additions).to_i,
      avg_deletions: PullRequest.average(:deletions).to_i
    }

    render json: @stats
  end

  private

  def filter_by_state(scope)
    return scope unless params[:state].present?
    scope.where(state: params[:state])
  end

  def filter_by_author(scope)
    return scope unless params[:author].present?
    scope.where(author_name: params[:author])
  end

  def sort_column
    %w[number title state github_created_at].include?(params[:sort]) ? params[:sort] : "github_created_at"
  end

  def sort_direction
    %w[asc desc].include?(params[:direction]) ? params[:direction] : "desc"
  end

  def find_related_insights
    comment_ids = @pull_request.comments.pluck(:id)
    return [] if comment_ids.empty?

    AiInsight.where("related_comments ?| array[:ids]", ids: comment_ids.map(&:to_s))
             .order(created_at: :desc)
             .limit(5)
  end
end
