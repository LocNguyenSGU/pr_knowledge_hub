require 'rails_helper'

RSpec.describe Tag, type: :model do
  describe 'associations' do
    it { should have_many(:comment_tags).dependent(:destroy) }
    it { should have_many(:comments).through(:comment_tags) }
  end

  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:category) }

    it 'validates uniqueness of name' do
      create(:tag)
      should validate_uniqueness_of(:name)
    end

    it 'validates category inclusion' do
      should validate_inclusion_of(:category).in_array(Tag::CATEGORIES)
    end
  end

  describe 'constants' do
    it 'has CATEGORIES defined' do
      expect(Tag::CATEGORIES).to be_an(Array)
      expect(Tag::CATEGORIES).to include('security', 'performance', 'code_style')
    end
  end
end
