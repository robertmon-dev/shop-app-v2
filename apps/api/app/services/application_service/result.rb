# frozen_string_literal: true

class ApplicationService
  Result = Struct.new(:success?, :data, :status, :errors, :message, keyword_init: true) do
    def failure? = !success?

    def then
      success? ? yield(data) : self
    end
  end
end
