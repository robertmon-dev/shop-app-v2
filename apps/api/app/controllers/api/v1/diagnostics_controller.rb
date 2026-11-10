# frozen_string_literal: true

module Api
  module V1
    class DiagnosticsController < Api::ApplicationController
      skip_before_action :authenticate_user!

      def readiness = render_probe(Diagnostics::Probe.readiness_probe)
      def health = render_probe(Diagnostics::Probe.health_probe)

      def metrics
        render plain: Prometheus::Client::Formats::Text.marshal(Diagnostics::Instrumentor.registry),
               content_type: 'text/plain; version=0.0.4'
      end

      private

      def render_probe(probe)
        errors = probe[:errors] || []
        return render_unavailable(probe, errors) if errors.any?

        respond_with_view(:probe, status: probe[:status], message: probe[:message], probe: probe)
      end

      def render_unavailable(probe, errors)
        render_failure(message: probe[:message] || 'Service unavailable', errors: errors, status: probe[:status],
                       data: probe[:details])
      end
    end
  end
end
