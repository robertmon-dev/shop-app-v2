# frozen_string_literal: true

require 'prometheus/client'

Rails.application.config.after_initialize do
  Diagnostics::Instrumentor.initialize_metrics
end
