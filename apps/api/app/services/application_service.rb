# frozen_string_literal: true

class ApplicationService
  include Results
  include ErrorHandling
  extend Results
  extend ErrorHandling

  def self.call(...) = new(...).call

  def call
    raise NotImplementedError, "#{self.class.name} must implement #call"
  end
end
