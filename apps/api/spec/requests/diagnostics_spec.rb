# frozen_string_literal: true

require 'rails_helper'
require 'prometheus/client'

RSpec.describe 'Api::V1::Diagnostics', type: :request do
  let(:json) { JSON.parse(response.body) }
  let!(:prometheus_text_format) do
    class_double('Prometheus::Client::Formats::Text').as_stubbed_const
  end

  describe 'GET /api/v1/diagnostics/readiness' do
    context 'when the application is ready' do
      before do
        allow(Diagnostics::Probe).to receive(:readiness_probe).and_return(
          {
            status: :ok,
            message: 'Application is ready to serve traffic.',
            details: { database: 'ok', redis: 'ok' }
          }
        )
        get '/api/v1/diagnostics/readiness'
      end

      it 'returns a 200 OK status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns a successful readiness response' do
        expect(json['success']).to be true
        expect(json['message']).to eq('Application is ready to serve traffic.')
        expect(json.dig('data', 'database')).to eq('ok')
      end
    end

    context 'when the application is not ready' do
      before do
        allow(Diagnostics::Probe).to receive(:readiness_probe).and_return(
          {
            status: :service_unavailable,
            message: 'Application is not ready.',
            errors: ['Database connection failed'],
            details: { database: 'down', redis: 'ok' }
          }
        )
        get '/api/v1/diagnostics/readiness'
      end

      it 'returns a 503 Service Unavailable status' do
        expect(response).to have_http_status(:service_unavailable)
      end

      it 'returns an unsuccessful readiness response with errors' do
        expect(json['success']).to be false
        expect(json['errors']).to include('Database connection failed')
        expect(json.dig('data', 'database')).to eq('down')
      end
    end
  end

  describe 'GET /api/v1/diagnostics/health' do
    context 'when the application is healthy' do
      before do
        allow(Diagnostics::Probe).to receive(:health_probe).and_return(
          {
            status: :ok,
            message: 'Application is healthy.',
            details: { uptime: '123d 4h 5m', sidekiq: 'running' }
          }
        )
        get '/api/v1/diagnostics/health'
      end

      it 'returns a 200 OK status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns a successful health response' do
        expect(json['success']).to be true
        expect(json['message']).to eq('Application is healthy.')
        expect(json.dig('data', 'sidekiq')).to eq('running')
      end
    end

    context 'when the application is unhealthy' do
      before do
        allow(Diagnostics::Probe).to receive(:health_probe).and_return(
          {
            status: :service_unavailable,
            message: 'Application is unhealthy.',
            errors: ['Sidekiq process not found'],
            details: { uptime: '123d 4h 5m', sidekiq: 'down' }
          }
        )
        get '/api/v1/diagnostics/health'
      end

      it 'returns a 503 Service Unavailable status' do
        expect(response).to have_http_status(:service_unavailable)
      end

      it 'returns an unsuccessful health response with errors' do
        expect(json['success']).to be false
        expect(json['message']).to eq('Application is unhealthy.')
        expect(json['errors']).to include('Sidekiq process not found')
      end
    end
  end

  describe 'GET /api/v1/diagnostics/metrics' do
    let(:prometheus_registry) { instance_double(Prometheus::Client::Registry) }
    let(:sample_metrics) { "# TYPE http_requests_total counter\nhttp_requests_total 5.0" }

    before do
      allow(Diagnostics::Instrumentor).to receive(:registry).and_return(prometheus_registry)
      allow(Prometheus::Client::Formats::Text).to receive(:marshal).with(prometheus_registry).and_return(sample_metrics)

      get '/api/v1/diagnostics/metrics'
    end

    it 'returns a 200 OK status' do
      expect(response).to have_http_status(:ok)
    end

    it 'returns metrics in the Prometheus text format' do
      expect(response.body).to eq(sample_metrics)
    end

    it 'returns the correct Content-Type header' do
      expect(response.content_type).to eq('text/plain; version=0.0.4; charset=utf-8')
    end
  end
end
