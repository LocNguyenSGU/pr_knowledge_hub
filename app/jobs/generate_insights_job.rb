# Background job to generate weekly AI insights
# Analyzes patterns and lessons learned from code reviews
class GenerateInsightsJob < ApplicationJob
  queue_as :low

  def perform(days = 7)
    Rails.logger.info "Generating AI insights for the last #{days} days"

    generator = Ai::InsightGenerator.new
    insight = generator.generate_weekly_insights(days: days)

    if insight
      Rails.logger.info "Generated insight ##{insight.id}: #{insight.title}"
    else
      Rails.logger.warn "No insight generated - insufficient data or error occurred"
    end
  end
end
