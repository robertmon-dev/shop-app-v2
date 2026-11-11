# frozen_string_literal: true

json.cache! ['category', category.id, category.updated_at] do
  json.id          category.id
  json.name        category.name

  json.parents category.parents do |parent_category|
    json.id   parent_category.id
    json.name parent_category.name
  end
end
