FactoryBot.define do
  factory :pull_request do
    github_id { "" }
    number { 1 }
    title { "MyString" }
    body { "MyText" }
    state { "MyString" }
    author_name { "MyString" }
    author_avatar { "MyString" }
    repository_name { "MyString" }
    repository_url { "MyString" }
    additions { 1 }
    deletions { 1 }
    changed_files_count { 1 }
    mergeable_state { "MyString" }
    draft { false }
    github_created_at { "2026-02-28 10:00:14" }
    github_updated_at { "2026-02-28 10:00:14" }
    closed_at { "2026-02-28 10:00:14" }
    merged_at { "2026-02-28 10:00:14" }
    last_synced_at { "2026-02-28 10:00:14" }
  end
end
