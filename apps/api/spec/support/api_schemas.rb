# frozen_string_literal: true

module ApiSchemas
  DATETIME = { type: :string, format: 'date-time' }.freeze
  DECIMAL = { type: :string, description: 'Decimal serialised as a string' }.freeze
  UUID = { type: :string, format: :uuid }.freeze
  ID = { type: :integer }.freeze
  TEXT = { type: :string }.freeze
  NULLABLE_TEXT = { type: :string, nullable: true }.freeze

  module_function

  def ref(name) = { '$ref' => "#/components/schemas/#{name}" }
  def list(name) = { type: :array, items: ref(name) }

  def object(properties, required: properties.keys)
    { type: :object, properties: properties, required: required.map(&:to_s) }
  end

  COMPONENTS = {
    User: object({ id: ID, mail: TEXT, phone: TEXT,
                   role: { type: :string, enum: %w[regular moderator admin entrepreneur] },
                   active: { type: :boolean }, verified: { type: :boolean },
                   created_at: DATETIME, updated_at: DATETIME },
                 required: %i[id mail active verified created_at updated_at]),
    UserDetail: object({ id: ID, name: TEXT, first_name: NULLABLE_TEXT, last_name: NULLABLE_TEXT,
                         created_at: DATETIME, updated_at: DATETIME }),
    Location: object({ id: ID, country: NULLABLE_TEXT, province: NULLABLE_TEXT, city: NULLABLE_TEXT,
                       postal_code: NULLABLE_TEXT, street: NULLABLE_TEXT, building_number: NULLABLE_TEXT,
                       apartment_number: NULLABLE_TEXT, created_at: DATETIME, updated_at: DATETIME }),
    EntrepreneurDetail: object(
      %i[business_name nip krs description offer industry business_phone_number business_mail website_address]
        .to_h { |key| [key, NULLABLE_TEXT] }
        .merge(id: ID, income: { nullable: true }, costs: { nullable: true }, funding_capital: { nullable: true },
               management_council_members: { nullable: true }, decision_makers: { nullable: true },
               created_at: DATETIME, updated_at: DATETIME)
    ),
    UserProfile: {
      allOf: [ref(:User)],
      type: :object,
      properties: { user_detail: ref(:UserDetail), locations: list(:Location),
                    entrepreneur_detail: ref(:EntrepreneurDetail) }
    },
    UserAction: object({ id: ID, action_type: TEXT, action: TEXT, created_at: DATETIME }),
    ProductPhoto: object({ id: UUID, url: NULLABLE_TEXT, thumbnail_url: NULLABLE_TEXT,
                           created_at: DATETIME, updated_at: DATETIME },
                         required: %i[id url created_at updated_at]),
    ProductLike: object({ id: ID, user_id: ID, created_at: DATETIME }),
    ProductComment: {
      type: :object,
      properties: { id: ID, user_id: ID, content: TEXT, parent_id: ID, created_at: DATETIME,
                    updated_at: DATETIME, replies: { type: :array, items: { type: :object } } },
      required: %w[id user_id content created_at updated_at]
    },
    Category: object({ id: UUID, name: TEXT,
                       parents: { type: :array, items: object({ id: UUID, name: TEXT }) } }),
    Product: object({ id: UUID, name: TEXT, description: NULLABLE_TEXT, price: DECIMAL,
                      stock_quantity: { type: :integer, nullable: true }, average_rating: { nullable: true }, likes_count: ID, comments_count: ID,
                      created_at: DATETIME, updated_at: DATETIME, photos: list(:ProductPhoto),
                      likes: list(:ProductLike), comments: list(:ProductComment), categories: list(:Category) },
                    required: %i[id name price likes_count comments_count photos likes comments categories]),
    OrderItem: object({ id: ID, product_name: TEXT, quantity: ID, price_at_purchase: DECIMAL, subtotal: DECIMAL }),
    Order: object({ id: ID, user_id: ID, total_amount: DECIMAL, status: TEXT, payment_status: TEXT,
                    created_at: DATETIME, updated_at: DATETIME, items: list(:OrderItem) }),
    Payment: {
      type: :object,
      properties: { id: ID, order_id: ID, amount: DECIMAL, currency: TEXT, status: TEXT,
                    payment_method: NULLABLE_TEXT, created_at: DATETIME, updated_at: DATETIME,
                    order: { '$ref' => '#/components/schemas/Order' } },
      required: %w[id order_id amount currency status created_at updated_at]
    },
    Refund: object({ id: ID, order_id: ID, user_id: ID, status: TEXT, payment_status: TEXT, reason: NULLABLE_TEXT,
                     description: NULLABLE_TEXT, refund_date: { type: :string, nullable: true },
                     created_at: DATETIME, updated_at: DATETIME }),
    InvoiceItem: object({ id: ID, name: TEXT, quantity: ID, unit_of_measure: NULLABLE_TEXT, net_price: DECIMAL,
                          vat_rate: DECIMAL, total_net_price: DECIMAL, total_vat_price: DECIMAL,
                          total_gross_price: DECIMAL }),
    Invoice: object({ id: ID, invoice_number: TEXT, order_id: ID, payment_id: { type: :integer, nullable: true },
                      buyer_name: NULLABLE_TEXT, buyer_tax_id: NULLABLE_TEXT, full_address: NULLABLE_TEXT,
                      sale_date: { type: :string, nullable: true }, due_date: { type: :string, nullable: true },
                      total_net: DECIMAL, tax_value: DECIMAL, total_gross: DECIMAL, url: NULLABLE_TEXT,
                      created_at: DATETIME, items: list(:InvoiceItem) }),
    CartItem: object({ item_id: ID, quantity: ID, price_at_purchase: DECIMAL, subtotal: DECIMAL,
                       product: object({ id: UUID, name: TEXT }) }),
    InvoiceDownload: object({ filename: TEXT, content_type: TEXT, pdf: { type: :string, description: 'Base64 PDF' } }),
    CategoryInput: object({ category: object({ name: TEXT, parent_id: { type: :string, nullable: true } },
                                             required: []) }),
    Cart: object({ total_amount: DECIMAL, items_count: ID, items: list(:CartItem) }),
    Meta: object({ current_page: ID, next_page: { type: :integer, nullable: true },
                   prev_page: { type: :integer, nullable: true }, total_pages: ID, total_count: ID })
  }.freeze

  def envelope(data = nil, meta: false)
    body = { type: :object,
             properties: { success: { type: :boolean }, message: TEXT },
             required: %w[success] }
    if data
      body[:properties][:data] = data
      body[:required] << 'data'
    end
    return body unless meta

    body[:properties][:meta] = ref(:Meta)
    body[:required] << 'meta'
    body
  end

  def failure
    { type: :object,
      properties: { success: { type: :boolean, enum: [false] }, message: TEXT, errors: { type: :array, items: TEXT },
                    data: { type: :object } },
      required: %w[success message errors] }
  end
end

module ApiSchemaHelpers
  def ref(name) = ApiSchemas.ref(name)
  def list(name) = ApiSchemas.list(name)

  def envelope_schema(properties = nil, meta: false, **inline)
    properties ||= inline
    data = properties.empty? ? nil : ApiSchemas.object(properties)
    ApiSchemas.envelope(data, meta: meta)
  end

  def data_schema(name, meta: false) = ApiSchemas.envelope(ApiSchemas.ref(name), meta: meta)
  def message_schema = ApiSchemas.envelope
  def failure_schema = ApiSchemas.failure
end

RSpec.configure do |config|
  config.extend ApiSchemaHelpers, file_path: %r{spec/integration}
end
