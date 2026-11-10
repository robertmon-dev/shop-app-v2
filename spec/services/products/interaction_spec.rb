# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Services::ProductInteractionService, type: :service do
  let!(:user) { create(:user) }
  let!(:product) { create(:product) }
  let(:service) { described_class.new(user) }

  describe '#like' do
    context 'when the user has not liked the product' do
      it 'creates a new ProductLike record' do
        expect do
          service.like(product)
        end.to change(ProductLike, :count).by(1)
      end

      it 'returns a successful result' do
        result = service.like(product)
        expect(result.success?).to be true
        expect(result.status).to eq(:created)
        expect(result.data[:product_like].user).to eq(user)
        expect(result.data[:product_like].product).to eq(product)
      end
    end

    context 'when the user has already liked the product' do
      before { create(:product_like, user: user, product: product) }

      it 'does not create a new ProductLike' do
        expect do
          service.like(product)
        end.not_to change(ProductLike, :count)
      end

      it 'returns a conflict failure result' do
        result = service.like(product)
        expect(result.success?).to be false
        expect(result.status).to eq(:conflict)
        expect(result.errors).to include('You have already liked this product.')
      end
    end
  end

  describe '#rate' do
    context 'with a valid rating' do
      context 'when creating a new rating' do
        it 'creates a new ProductRate record' do
          expect do
            service.rate(product, 5, 'Great!')
          end.to change(ProductRate, :count).by(1)
        end

        it 'returns a successful :created result' do
          result = service.rate(product, 5, 'Great!')
          expect(result.success?).to be true
          expect(result.status).to eq(:created)
          expect(result.message).to eq('Product rated successfully.')
        end
      end

      context 'when updating an existing rating' do
        let!(:existing_rate) { create(:product_rate, user: user, product: product, rating: 3) }

        it 'updates the existing rating' do
          service.rate(product, 5, 'Updated my thoughts.')
          expect(existing_rate.reload.rating).to eq(5)
          expect(existing_rate.reload.comment).to eq('Updated my thoughts.')
        end

        it 'returns a successful :ok result' do
          result = service.rate(product, 5)
          expect(result.success?).to be true
          expect(result.status).to eq(:ok)
          expect(result.message).to eq('Product rating updated successfully.')
        end
      end
    end

    context 'with an invalid rating' do
      it 'does not create a ProductRate' do
        expect do
          service.rate(product, 6)
        end.not_to change(ProductRate, :count)
      end

      it 'returns an unprocessable_content failure result' do
        result = service.rate(product, 0)
        expect(result.success?).to be false
        expect(result.status).to eq(:unprocessable_content)
        expect(result.errors).to include('Rating must be an integer between 1 and 5.')
      end
    end
  end

  describe '#add_comment' do
    context 'with valid content' do
      it 'creates a new top-level comment' do
        expect do
          service.add_comment(product, 'This is a top-level comment.')
        end.to change(Comment, :count).by(1)
        expect(Comment.last.parent).to be_nil
      end

      it 'returns a successful result for a top-level comment' do
        result = service.add_comment(product, 'This is a top-level comment.')
        expect(result.success?).to be true
        expect(result.status).to eq(:created)
      end

      context 'when replying to another comment' do
        let!(:parent_comment) { create(:comment, product: product) }

        it 'creates a new comment with the correct parent' do
          service.add_comment(product, 'This is a reply.', parent_comment.id)
          expect(Comment.last.parent).to eq(parent_comment)
        end
      end
    end

    context 'with invalid parameters' do
      it 'returns a failure result for blank content' do
        result = service.add_comment(product, '')
        expect(result.success?).to be false
        expect(result.errors.first).to eq("Content can't be blank")
      end

      it 'returns a failure result for an invalid parent_id' do
        result = service.add_comment(product, 'A comment', -1)
        expect(result.success?).to be false
        expect(result.errors.first).to eq('Unknown error has occured during the operation')
      end
    end
  end
end
