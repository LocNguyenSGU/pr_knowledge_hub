FactoryBot.define do
  factory :pull_request do
    sequence(:github_id) { |n| n + 100000 }
    sequence(:number) { |n| n }
    title { "Add user authentication feature" }
    body { "This PR adds user authentication with JWT tokens" }
    state { "open" }
    author_name { "octocat" }
    author_avatar { "https://github.com/images/error/octocat_happy.gif" }
    repository_name { "owner/repo" }
    repository_url { "https://github.com/owner/repo/pull/#{number}" }
    additions { 150 }
    deletions { 50 }
    changed_files_count { 5 }
    mergeable_state { "clean" }
    draft { false }
    github_created_at { 3.days.ago }
    github_updated_at { 1.day.ago }
    closed_at { nil }
    merged_at { nil }
    last_synced_at { Time.current }

    trait :closed do
      state { "closed" }
      closed_at { 1.day.ago }
    end

    trait :merged do
      state { "merged" }
      closed_at { 1.day.ago }
      merged_at { 1.day.ago }
    end

    trait :draft do
      draft { true }
    end
  end
end
