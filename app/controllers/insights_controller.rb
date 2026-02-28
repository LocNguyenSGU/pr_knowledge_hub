class InsightsController < ApplicationController
  def index
    @insights = AiInsight.order(created_at: :desc)
                        .then { |scope| filter_by_type(scope) }
                        .page(params[:page]).per(15)

    @insight_types = AiInsight.distinct.pluck(:insight_type).compact

    @stats = {
      total: AiInsight.count,
      patterns: AiInsight.where(insight_type: "pattern").count,
      lessons: AiInsight.where(insight_type: "lesson").count,
      recommendations: AiInsight.where(insight_type: "recommendation").count
    }
  end

  def show
    @insight = AiInsight.find(params[:id])
    @related_comments = find_related_comments
  end

  private

  def filter_by_type(scope)
    return scope unless params[:type].present? && [ "pattern", "lesson", "recommendation" ].include?(params[:type])
    scope.where(insight_type: params[:type])
  end

  def find_related_comments
    return [] if @insight.related_comments.blank?

    Comment.where(id: @insight.related_comments)
           .includes(:pull_request, :tags)
           .order(github_created_at: :desc)
  end
end
