# frozen_string_literal: true

module Services
  class S3UploadService
    include Concerns::Handlers
    include Concerns::ResultHelpers

    DEFAULT_CONTENT_TYPE = 'application/octet-stream'

    def self.call(**) = new(**).call

    def initialize(data:, filename:, content_type: DEFAULT_CONTENT_TYPE, attach_to: nil, as: nil)
      @data = data
      @filename = filename
      @content_type = content_type
      @attach_to = attach_to
      @as = as
    end

    def call
      return missing_data_result if @data.blank? || @filename.blank?

      with_error_handling do
        blob = create_blob
        attach(blob)

        success_result(data: { blob: blob, url: url_for(blob), key: blob.key },
                       message: "#{@filename} uploaded successfully", status: :created)
      end
    end

    private

    def create_blob
      ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new(@data.to_s),
        filename: @filename,
        content_type: @content_type
      )
    end

    def attach(blob)
      return if @attach_to.blank? || @as.blank?

      @attach_to.public_send(@as).attach(blob)
    end

    def url_for(blob)
      blob.url(expires_in: 1.week)
    rescue StandardError
      Rails.application.routes.url_helpers.rails_blob_url(blob, host: ENV.fetch('APP_HOST', 'http://localhost:3000'))
    end

    def missing_data_result
      unprocessable_content_with_errors_result(errors: ['File data and filename are required.'],
                                               message: 'Nothing to upload.')
    end
  end
end
