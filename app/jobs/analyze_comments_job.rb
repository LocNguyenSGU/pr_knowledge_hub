# Background job to analyze and tag comments using AI
# Processes unanalyzed comments in batches
class AnalyzeCommentsJob < ApplicationJob
  queue_as :default

  BATCH_SIZE = 50

  def perform
    unanalyzed_comments = Comment.unanalyzed.limit(BATCH_SIZE)

    if unanalyzed_comments.empty?
      Rails.logger.info "No unanalyzed comments to process"
      return
    end

    Rails.logger.info "Analyzing #{unanalyzed_comments.count} comments"

    classifier = Ai::CommentClassifier.new
    results = classifier.classify_batch(unanalyzed_comments)

    Rails.logger.info "Analysis complete: #{results[:success]} successful, #{results[:failed]} failed, #{results[:skipped]} skipped"
  end
end
