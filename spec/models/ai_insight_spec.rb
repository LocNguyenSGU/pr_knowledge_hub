require 'rails_helper'

RSpec.describe AiInsight, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:insight_type) }
    it { should validate_presence_of(:title) }
    it { should validate_presence_of(:content) }

    it 'validates insight_type inclusion' do
      should validate_inclusion_of(:insight_type).in_array(%w[pattern lesson recommendation])
    end
  end

  describe 'scopes' do
    let!(:pattern) { create(:ai_insight, :pattern) }
    let!(:lesson) { create(:ai_insight, :lesson) }
    let!(:recommendation) { create(:ai_insight, :recommendation) }

    describe '.patterns' do
      it 'returns only pattern insights' do
        expect(AiInsight.patterns).to include(pattern)
        expect(AiInsight.patterns).not_to include(lesson)
      end
    end

    describe '.lessons' do
      it 'returns only lesson insights' do
        expect(AiInsight.lessons).to include(lesson)
        expect(AiInsight.lessons).not_to include(pattern)
      end
    end

    describe '.recommendations' do
      it 'returns only recommendation insights' do
        expect(AiInsight.recommendations).to include(recommendation)
        expect(AiInsight.recommendations).not_to include(lesson)
      end
    end
  end
end
