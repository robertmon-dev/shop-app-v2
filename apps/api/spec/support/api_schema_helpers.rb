# frozen_string_literal: true

module ApiSchemaHelpers
  META_SCHEMA = {
    type: :object,
    properties: {
      current_page: { type: :integer },
      next_page: { type: :integer, nullable: true },
      prev_page: { type: :integer, nullable: true },
      total_pages: { type: :integer },
      total_count: { type: :integer }
    },
    required: %w[current_page total_pages total_count]
  }.freeze

  def envelope_schema(properties = {}, meta: false)
    body = {
      type: :object,
      properties: { success: { type: :boolean }, message: { type: :string } },
      required: %w[success]
    }
    body[:properties][:data] = { type: :object, properties: properties, required: properties.keys.map(&:to_s) }
    body[:required] << 'data' if properties.any?
    body[:properties][:meta] = META_SCHEMA if meta
    body[:required] << 'meta' if meta
    body
  end
end

RSpec.configure do |config|
  config.extend ApiSchemaHelpers, file_path: %r{spec/integration}
end
