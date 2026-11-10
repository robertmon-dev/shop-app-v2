# frozen_string_literal: true

module Services
  class ProductInteractionService
    include Concerns::Handlers
    include Concerns::ResultHelpers

    def initialize(user)
      @user = user
    end

    def like(product)
      with_error_handling do
        if ProductLike.exists?(user: @user, product: product)
          return conflict_result(errors: ['You have already liked this product.'], message: 'Product already liked.')
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
          not_found_error_result(errors: ['You have not liked this product.'], message: 'Product like not found')
        end

        product_like.destroy!
        destroy_success_result(message: 'Product unliked successfully')
      end
    end

    def rate(product, rating, comment = nil)
      with_error_handling do
        unless rating.present? && (1..5).include?(rating.to_i)
          return unprocessable_content_with_errors_result(errors: ['Rating must be an integer between 1 and 5.'],
                                                          message: 'Invalid rating value')
        end
        product_rate = ProductRate.find_or_initialize_by(user: @user, product: product)
        product_rate.update!(rating: rating.to_i, comment: comment)

        success_result(data: { product_rate: product_rate },
                       status: product_rate.previous_changes.key?('id') ? :created : :ok,
                       message: product_rate.previous_changes.key?('id') ? 'Product rated successfully.' : 'Product rating updated successfully.')
      end
    end

    def add_comment(product, content, parent_id = nil)
      return not_found_result(message: 'Product not found') unless product

      with_error_handling do
        result = build_new_comment(product, content, parent_id)

        if result.is_a?(Comment)
          result.save!
          success_result(data: { comment: result }, message: 'Successfully added comment', status: :created)
        else
          result
        end
      end
    end

    def update_comment(comment, new_content)
      with_error_handling do
        return not_found_result(errors: ['Comment not found'], message: 'Comment not found') unless comment.present?

        unless comment.user == @user || @user.admin? || @user.moderator?
          return forbidden_result(errors: ['You are not authorized to edit this comment'],
                                  message: 'Authorization failed')
        end

        comment.update!(content: new_content)
        success_result(data: { comment: comment }, message: 'Comment updated successfully')
      end
    end

    def remove_comment(comment)
      with_error_not_destroyed_handling do
        unless comment.user == @user || @user.admin? || @user.moderator?
          return forbidden_result(errors: ['You are not authorized to remove this comment'],
                                  message: 'Authorization failed')
        end
        comment.destroy!
        destroy_success_result(message: 'Comment removed successfully')
      end
    end

    def build_new_comment(product, content, parent_id)
      if content.blank?
        return unprocessable_content_with_errors_result(errors: ["Content can't be blank"],
                                                        message: "Comment content can't be empty.")
      end

      comment = product.comments.new(user: @user, content: content)

      if parent_id.present?
        error_result = assign_parent(comment, product, parent_id)
        return error_result if error_result
      end

      comment
    end

    def assign_parent(comment, product, parent_id)
      parent = product.comments.find_by(id: parent_id)

      return unprocessable_content_with_errors_result(message: 'Invalid parent comment ID') unless parent

      comment.parent = parent
      nil
    end
  end
end
