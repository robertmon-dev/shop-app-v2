# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::DiagnosticsController, type: :controller do
  render_views

  before do
    allow(Diagnostics::Probe).to receive(:readiness_probe).and_return(
      status: :ok, message: 'Application is ready', errors: [], details: {}
    )
    allow(Diagnostics::Probe).to receive(:health_probe).and_return(
      status: :ok, message: 'Application is healthy', errors: [], details: { database: true, redis: true }
    )
  end

  describe 'GET #readiness' do
    context 'when the application is ready' do
      it 'returns a success status and message' do
        get :readiness, format: :json
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)

        expect(json_response['success']).to be true
        expect(json_response['message']).to eq('Application is ready')
      end
    end

    context 'when the readiness check fails' do
      before do
        allow(Diagnostics::Probe).to receive(:readiness_probe).and_return(
          status: :service_unavailable, message: 'Application not ready', errors: ['Readiness check failed: DB error'], details: {}
        )
      end

      it 'returns a service unavailable status and errors' do
        get :readiness, format: :json
        expect(response).to have_http_status(:service_unavailable)
        json_response = JSON.parse(response.body)

        expect(json_response['success']).to be false
        expect(json_response['errors']).to include('Readiness check failed: DB error')
      end
    end
  end

  describe 'GET #health' do
    context 'when all components are healthy' do
      it 'returns a success status and detailed information' do
        get :health, format: :json
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)

        expect(json_response['success']).to be true
        expect(json_response['message']).to eq('Application is healthy')
        expect(json_response['data']['database']).to be true
        expect(json_response['data']['redis']).to be true
      end
    end

    context 'when a component is unhealthy' do
      before do
        allow(Diagnostics::Probe).to receive(:health_probe).and_return(
          status: :service_unavailable,
          message: 'Application unhealthy',
          errors: ['Redis check failed: Connection refused'],
          details: { database: true, redis: false }
        )
      end

      it 'returns a service unavailable status and errors' do
        get :health, format: :json
        expect(response).to have_http_status(:service_unavailable)
        json_response = JSON.parse(response.body)

        expect(json_response['success']).to be false
        expect(json_response['errors']).to include('Redis check failed: Connection refused')
        expect(json_response['data']['redis']).to be false
      end
    end
  end

  describe 'GET #metrics' do
    it 'returns metrics in Prometheus text format' do
      prometheus_text_format = class_double('Prometheus::Client::Formats::Text').as_stubbed_const

      allow(Diagnostics::Instrumentor).to receive(:registry).and_return(double('registry'))
      allow(prometheus_text_format).to receive(:marshal).and_return('fake metrics')

      get :metrics

      expect(response).to have_http_status(:ok)
      expect(response.body).to eq('fake metrics')
      expect(response.content_type).to eq('text/plain; version=0.0.4; charset=utf-8')
    end
  end
end
