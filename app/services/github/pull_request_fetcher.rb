module Github
  class PullRequestFetcher
    attr_reader :repository_name, :pr_number, :client
    
    def initialize(repository_name, pr_number)
      @repository_name = repository_name
      @pr_number = pr_number
      @client = Github::Client.new
    end
    
    def fetch
      pr_data = client.pull_request(repository_name, pr_number)
      return nil unless pr_data
      
      upsert_pull_request(pr_data)
    end
    
    def fetch_all(state: 'all')
      prs = client.pull_requests(repository_name, state: state)
      
      prs.map do |pr_data|
        upsert_pull_request(pr_data)
      end.compact
    end
    
    private
    
    def upsert_pull_request(pr_data)
      attributes = {
        github_id: pr_data.id,
        number: pr_data.number,
        title: pr_data.title,
        body: pr_data.body,
        state: determine_state(pr_data),
        author_name: pr_data.user.login,
        author_avatar: pr_data.user.avatar_url,
        repository_name: repository_name,
        repository_url: pr_data.html_url,
        additions: pr_data.additions || 0,
        deletions: pr_data.deletions || 0,
        changed_files_count: pr_data.changed_files || 0,
        mergeable_state: pr_data.mergeable_state,
        draft: pr_data.draft || false,
        github_created_at: pr_data.created_at,
        github_updated_at: pr_data.updated_at,
        closed_at: pr_data.closed_at,
        merged_at: pr_data.merged_at,
        last_synced_at: Time.current
      }
      
      pr = PullRequest.find_or_initialize_by(github_id: pr_data.id)
      pr.assign_attributes(attributes)
      
      if pr.save
        Rails.logger.info("Synced PR ##{pr.number}: #{pr.title}")
        pr
      else
        Rails.logger.error("Failed to save PR ##{pr_data.number}: #{pr.errors.full_messages.join(', ')}")
        nil
      end
    end
    
    def determine_state(pr_data)
      return 'merged' if pr_data.merged_at.present?
      pr_data.state
    end
  end
end
