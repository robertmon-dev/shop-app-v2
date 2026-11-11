# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Comment, type: :model do
  describe 'associations' do
    it { should belong_to(:product).inverse_of(:comments) }
    it { should belong_to(:user).inverse_of(:comments) }
    it { should belong_to(:parent).class_name('Comment').optional.counter_cache(:replies_count).inverse_of(:replies) }
    it {
      should have_many(:replies).class_name('Comment').with_foreign_key('parent_id').dependent(:destroy).inverse_of(:parent)
    }
  end

  describe 'validations' do
    it { should validate_presence_of(:content) }
    it { should validate_numericality_of(:replies_count).is_greater_than_or_equal_to(0) }
  end

  describe 'scopes' do
    let!(:top_level_comment) { create(:comment, parent: nil, created_at: 2.days.ago) }
    let!(:reply_comment) { create(:comment, parent: top_level_comment, created_at: 1.day.ago) }
    let!(:another_top_level_comment) { create(:comment, parent: nil, created_at: Time.current) }

    it '.top_level returns comments without a parent' do
      expect(Comment.top_level).to contain_exactly(top_level_comment, another_top_level_comment)
    end

    it '.recent returns comments ordered by creation date descending' do
      expect(Comment.recent).to eq([another_top_level_comment, reply_comment, top_level_comment])
    end
  end

  describe 'instance methods' do
    let(:top_level_comment) { create(:comment, parent: nil) }
    let(:reply_comment) { create(:comment, parent: top_level_comment) }

    it '#top_level? returns true for top-level comments' do
      expect(top_level_comment.top_level?).to be true
    end

    it '#top_level? returns false for reply comments' do
      expect(reply_comment.top_level?).to be false
    end
  end

  describe 'counter_cache for replies_count' do
    let(:parent_comment) { create(:comment) }

    it 'increments replies_count when a reply is created' do
      expect { create(:comment, parent: parent_comment) }.to change { parent_comment.reload.replies_count }.by(1)
    end

    it 'decrements replies_count when a reply is destroyed' do
      reply = create(:comment, parent: parent_comment)
      expect { reply.destroy }.to change { parent_comment.reload.replies_count }.by(-1)
    end

    it 'does not change replies_count when a non-reply comment is created' do
      expect { create(:comment) }.not_to(change { parent_comment.reload.replies_count })
    end
  end
end
