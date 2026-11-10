# frozen_string_literal: true

require 'swagger_helper'
require 'prometheus/client/formats/text'

describe 'Diagnostics API' do
  path '/api/v1/diagnostics/readiness' do
    get 'Checks if the application is ready to serve traffic' do
      tags 'Diagnostics'
      produces 'application/json'

      context 'when application is ready' do
        response '200', 'application is ready' do
          schema type: :object, properties: {
            success: { type: :boolean, example: true },
            message: { type: :string, example: 'Application is ready.' },
            details: { type: :object, properties: { database: { type: :string, example: 'ok' } } }
          }

          before do
            allow(Diagnostics::Probe).to receive(:readiness_probe).and_return(
              { status: :ok, message: 'Application is ready.', details: { database: 'ok' } }
            )
          end

          after do |example|
            example.metadata[:response][:content] =
              { 'application/json' => { example: JSON.parse(response.body, symbolize_names: true) } }
          end
          run_test!
        end
      end

      context 'when application is not ready' do
        response '503', 'application is not ready' do
          schema type: :object, properties: {
            success: { type: :boolean, example: false },
            message: { type: :string, example: 'Application is not ready.' },
            errors: { type: :array, items: { type: :string } },
            details: { type: :object, properties: { database: { type: :string, example: 'error' } } }
          }

          before do
            allow(Diagnostics::Probe).to receive(:readiness_probe).and_return(
              { status: :service_unavailable, message: 'Application is not ready.',
                errors: ['Database connection failed'], details: { database: 'error' } }
            )
          end

          after do |example|
            example.metadata[:response][:content] =
              { 'application/json' => { example: JSON.parse(response.body, symbolize_names: true) } }
          end
          run_test!
        end
      end
    end
  end

  path '/api/v1/diagnostics/health' do
    get 'Checks the ongoing health of the application' do
      tags 'Diagnostics'
      produces 'application/json'

      context 'when application is healthy' do
        response '200', 'application is healthy' do
          schema type: :object, properties: {
            success: { type: :boolean, example: true },
            message: { type: :string, example: 'Application is healthy.' },
            details: { type: :object,
                       properties: { database: { type: :string, example: 'ok' },
                                     redis: { type: :string, example: 'ok' } } }
          }

          before do
            allow(Diagnostics::Probe).to receive(:health_probe).and_return(
              { status: :ok, message: 'Application is healthy.', details: { database: 'ok', redis: 'ok' } }
            )
          end

          after do |example|
            example.metadata[:response][:content] =
              { 'application/json' => { example: JSON.parse(response.body, symbolize_names: true) } }
          end
          run_test!
        end
      end
    end
  end

  path '/api/v1/diagnostics/metrics' do
    get 'Exposes application metrics in Prometheus format' do
      tags 'Diagnostics'
      produces 'text/plain'

      response '200', 'metrics returned' do
        schema type: :string

        before do
          allow(Prometheus::Client::Formats::Text).to receive(:marshal).and_return("http_requests_total 1\n")
        end

        after do |example|
          example.metadata[:response][:content] = { 'text/plain' => { example: response.body } }
        end
        run_test!
      end
    end
  end
end
