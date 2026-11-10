# frozen_string_literal: true

module Services
  class ProductPhotoCreationService
    include Concerns::Handlers
    include Concerns::ResultHelpers

    PERMITTED_CONTENT_TYPES = %w[image/png image/jpeg image/webp image/gif].freeze
    MAX_BYTES = 10.megabytes

    def self.call(**) = new(**).call

    def initialize(image:, product: nil)
      @image = image
      @product = product
    end

    def call
      invalid = validate_image
      return invalid if invalid

      with_error_handling do
        photo = ProductPhoto.new(product: @product)
        photo.image.attach(@image)
        photo.save!
        photo.update!(url: photo.image_url)

        success_result(data: { product_photo: photo, product: @product&.reload },
                       message: 'Photo uploaded successfully', status: :created)
      end
    end

    private

    def validate_image
      return missing_image_result if @image.blank?
      return unsupported_type_result unless PERMITTED_CONTENT_TYPES.include?(content_type)
      return too_large_result if size.to_i > MAX_BYTES

      nil
    end

    def content_type = @image.try(:content_type).to_s
    def size = @image.try(:size)

    def missing_image_result
      unprocessable_content_with_errors_result(errors: ['Image is required.'], message: 'No image provided.')
    end

    def unsupported_type_result
      unprocessable_content_with_errors_result(
        errors: ["Unsupported image type: #{content_type.presence || 'unknown'}"],
        message: 'Unsupported image type.'
      )
    end

    def too_large_result
      unprocessable_content_with_errors_result(
        errors: ["Image exceeds the #{MAX_BYTES / 1.megabyte} MB limit."],
        message: 'Image too large.'
      )
    end
  end
end
