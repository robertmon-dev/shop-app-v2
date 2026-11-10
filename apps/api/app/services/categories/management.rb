# frozen_string_literal: true

module Categories
  class Management < ApplicationService
    def self.create(category_params)
      with_error_not_destroyed_handling do
        category = Category.new(category_params)
        ActiveRecord::Base.transaction do
          category.save!
        end

        success_result(data: { category: category }, message: 'Category created successfully', status: :created)
      end
    end

    def self.update(category, category_params)
      return missing_result('Category') unless category

      with_error_handling do
        category.update!(category_params)
        success_result(data: { category: category }, message: 'Category updated successfully')
      end
    end

    def self.destroy(category)
      return missing_result('Category') unless category

      with_error_not_destroyed_handling do
        category.destroy!
        destroy_success_result(message: 'Category deleted successfully')
      end
    end
  end
end
