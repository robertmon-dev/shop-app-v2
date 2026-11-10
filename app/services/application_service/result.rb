# frozen_string_literal: true

module Services
  Result = Struct.new(:success?, :data, :status, :errors, :message, keyword_init: true) do
    def then
      if success?
        yield(data)
      else
        self
      end
    end
  end
end
