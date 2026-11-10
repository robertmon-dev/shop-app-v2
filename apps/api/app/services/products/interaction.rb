# frozen_string_literal: true

module Products
  class Interaction < ApplicationService
    def initialize(user)
      @user = user
    end

    def like(product)
      with_error_handling do
        if ProductLike.exists?(user: @user, product: product)
          next conflict_result(errors: ['You have already liked this product.'], message: 'Product already liked.')
        end

        product_like = ProductLike.create!(user: @user, product: product)
        success_result(data: { product_like: product_like }, message: 'Product like created successfully',
                       status: :created)
      end
    end

    def unlike(product)
      with_error_handling do
        product_like = ProductLike.find_by(user: @user, product: product)
        unless product_like
          next not_found_result(errors: ['You have not liked this product.'],
                                message: 'Product like not found')
        end

        product_like.destroy!
        destroy_success_result(message: 'Product unliked successfully')
      end
    end

    def rate(product, rating, comment = nil)
      unless valid_rating?(rating)
        return invalid_result('Invalid rating value',
                              errors: ['Rating must be an integer between 1 and 5.'])
      end

      with_error_handling do
        product_rate = ProductRate.find_or_initialize_by(user: @user, product: product)
        product_rate.update!(rating: rating.to_i, comment: comment)
        rate_success_result(product_rate)
      end
    end

    def add_comment(product, content, parent_id = nil)
      return missing_result('Product') unless product
      return invalid_result("Comment content can't be empty.", errors: ["Content can't be blank"]) if content.blank?

      with_error_handling do
        comment = product.comments.new(user: @user, content: content)
        parent_error = assign_parent(comment, product, parent_id)
        next parent_error if parent_error

        comment.save!
        success_result(data: { comment: comment }, message: 'Successfully added comment', status: :created)
      end
    end

    def update_comment(comment, new_content)
      with_error_handling do
        next missing_result('Comment') unless comment
        next unauthorized_comment_result('edit') unless can_manage?(comment)

        comment.update!(content: new_content)
        success_result(data: { comment: comment }, message: 'Comment updated successfully')
      end
    end

    def remove_comment(comment)
      return missing_result('Comment') unless comment
      return unauthorized_comment_result('remove') unless can_manage?(comment)

      with_error_not_destroyed_handling do
        comment.destroy!
        destroy_success_result(message: 'Comment removed successfully')
      end
    end

    private

    def valid_rating?(rating)
      rating.present? && (1..5).cover?(rating.to_i)
    end

    def rate_success_result(product_rate)
      created = product_rate.previous_changes.key?('id')
      success_result(data: { product_rate: product_rate }, status: created ? :created : :ok,
                     message: created ? 'Product rated successfully.' : 'Product rating updated successfully.')
    end

    def can_manage?(comment)
      comment.user == @user || @user.admin? || @user.moderator?
    end

    def unauthorized_comment_result(action)
      forbidden_result(errors: ["You are not authorized to #{action} this comment"], message: 'Authorization failed')
    end

    def assign_parent(comment, product, parent_id)
      return if parent_id.blank?

      parent = product.comments.find_by(id: parent_id)
      return invalid_result('Invalid parent comment ID') unless parent

      comment.parent = parent
      nil
    end
  end
end
