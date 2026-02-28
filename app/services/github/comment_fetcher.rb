module Github
  class CommentFetcher
    attr_reader :repository_name, :pr_number, :client, :pull_request
    
    def initialize(repository_name, pr_number)
      @repository_name = repository_name
      @pr_number = pr_number
      @client = Github::Client.new
      @pull_request = PullRequest.find_by(number: pr_number)
    end
    
    def fetch
      unless pull_request
        Rails.logger.error("Pull request ##{pr_number} not found in database. Please sync PR first.")
        return []
      end
      
      comments = []
      
      # Fetch 3 types of comments
      comments += fetch_issue_comments
      comments += fetch_review_comments
      comments += fetch_reviews
      
      Rails.logger.info("Synced #{comments.size} comments for PR ##{pr_number}")
      comments
    end
    
    private
    
    def fetch_issue_comments
      comments_data = client.issue_comments(repository_name, pr_number)
      upsert_comments(comments_data, 'issue_comment')
    end
    
    def fetch_review_comments
      comments_data = client.review_comments(repository_name, pr_number)
      upsert_comments(comments_data, 'review_comment')
    end
    
    def fetch_reviews
      reviews_data = client.reviews(repository_name, pr_number)
      
      # Only save reviews that have a body (not just approval/changes requested without comment)
      reviews_with_body = reviews_data.select { |r| r.body.present? }
      upsert_comments(reviews_with_body, 'review')
    end
    
    def upsert_comments(comments_data, comment_type)
      comments_data.map do |comment_data|
        next if comment_data.body.blank?
        
        attributes = {
          github_id: comment_data.id,
          pull_request_id: pull_request.id,
          body: comment_data.body,
          author_name: comment_data.user.login,
          author_avatar: comment_data.user.avatar_url,
          author_role: determine_author_role(comment_data),
          comment_type: comment_type,
          path: comment_data.try(:path),
          position: comment_data.try(:position),
          line: comment_data.try(:line) || comment_data.try(:original_line),
          github_created_at: comment_data.created_at,
          github_updated_at: comment_data.updated_at
        }
        
        comment = Comment.find_or_initialize_by(github_id: comment_data.id)
        comment.assign_attributes(attributes)
        
        if comment.save
          Rails.logger.debug("Synced comment by #{comment.author_name}")
          comment
        else
          Rails.logger.error("Failed to save comment: #{comment.errors.full_messages.join(', ')}")
          nil
        end
      end.compact
    end
    
    def determine_author_role(comment_data)
      if comment_data.user.login == pull_request.author_name
        'author'
      elsif comment_data.try(:author_association) == 'OWNER'
        'owner'
      else
        'reviewer'
      end
    end
  end
end
