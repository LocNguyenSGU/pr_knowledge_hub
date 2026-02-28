FactoryBot.define do
  factory :ai_insight do
    insight_type { %w[pattern lesson recommendation].sample }
    title { "Code Review Insights - Week of #{Date.today.strftime('%B %d, %Y')}" }
    content { "Summary: This week showed improvements in code quality.\n\nPatterns:\n- Better error handling\n- Improved testing\n\nRecommendations:\n- Continue with current practices" }
    related_comments { [] }
    confidence_score { 0.85 }
    ai_model { "gemini-2.5-flash, gpt-4o-mini" }

    trait :with_comments do
      after(:create) do |insight|
        comments = create_list(:comment, 3)
        insight.update(related_comments: comments.map(&:id))
      end
    end

    trait :pattern do
      insight_type { "pattern" }
    end

    trait :lesson do
      insight_type { "lesson" }
    end

    trait :recommendation do
      insight_type { "recommendation" }
    end
  end
end
