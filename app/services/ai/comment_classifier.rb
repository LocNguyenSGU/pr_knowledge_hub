module Ai
  # Service to automatically classify and tag comments using AI
  class CommentClassifier
    def initialize
      @gemini = GeminiClient.new
    end

    # Classify a single comment and assign tags
    # @param comment [Comment] The comment to classify
    # @return [Boolean] Success status
    def classify(comment)
      return false if comment.body.blank?

      Rails.logger.info "Classifying comment ##{comment.id}"

      category_names = @gemini.classify_comment(comment.body)

      if category_names.empty?
        Rails.logger.info "No categories identified for comment ##{comment.id}"
        comment.update(analyzed: true)
        return true
      end

      # Find or create tags
      tags = category_names.map do |category_name|
        Tag.find_by(name: category_name)
      end.compact

      # Assign tags to comment
      comment.tags = tags
      comment.update(analyzed: true)

      Rails.logger.info "Comment ##{comment.id} tagged with: #{tags.map(&:name).join(', ')}"
      true

    rescue StandardError => e
      Rails.logger.error "Failed to classify comment ##{comment.id}: #{e.message}"
      false
    end

    # Classify multiple comments in batch
    # @param comments [ActiveRecord::Relation<Comment>] Comments to classify
    # @return [Hash] Results with success and failure counts
    def classify_batch(comments)
      results = { success: 0, failed: 0, skipped: 0 }

      comments.find_each do |comment|
        if comment.analyzed?
          results[:skipped] += 1
          next
        end

        if classify(comment)
          results[:success] += 1
        else
          results[:failed] += 1
        end

        # Rate limiting: pause between requests
        sleep 0.5
      end

      Rails.logger.info "Batch classification complete: #{results}"
      results
    end

    # Re-classify comments that have no tags
    # @param limit [Integer] Maximum number of comments to process
    # @return [Hash] Results
    def reclassify_untagged(limit: 50)
      untagged = Comment.analyzed
                        .left_joins(:comment_tags)
                        .where(comment_tags: { id: nil })
                        .limit(limit)

      Rails.logger.info "Re-classifying #{untagged.count} untagged comments"

      # Mark as unanalyzed so they get processed
      untagged.update_all(analyzed: false)

      classify_batch(untagged)
    end
  end
end
