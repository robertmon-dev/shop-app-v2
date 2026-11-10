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
        @status = probe[:status]
        @message = probe[:message]
        @errors = probe[:errors] || []
        @success = @errors.empty?
        @data = probe[:details] ? { details: probe[:details] } : {}

        render :_probe_result, status: @status
      end
    end
  end
end
