# frozen_string_literal: true

module Services
  class CategoryManagementService
    extend Concerns::Handlers
    extend Concerns::ResultHelpers

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
      return not_found_result(errors: ['Category not found'], message: 'Category not found') unless category

      with_error_handling do
        category.update!(category_params)
        success_result(data: { category: category }, message: 'Category updated successfully')
      end
    end

    def self.destroy(category)
      return not_found_result(errors: ['Category not found'], message: 'Category not found') unless category

      with_error_not_destroyed_handling do
        category.destroy!
        destroy_success_result(message: 'Category deleted successfully')
      end
    end
  end
end
