# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Services::DiagnosticsService, type: :service do
  let(:instrumentor) { class_double(Services::Instrumentor).as_stubbed_const }

  before do
    allow(instrumentor).to receive(:check_performed)
  end

  describe '.readiness_probe' do
    context 'when the database connection is successful' do
      before do
        allow(ActiveRecord::Base).to receive(:connection).and_return(double(execute: true))
      end

      it 'returns an :ok status' do
        result = described_class.readiness_probe
        expect(result[:status]).to eq(:ok)
      end

      it 'instruments the check' do
        described_class.readiness_probe
        expect(instrumentor).to have_received(:check_performed).with(:readiness)
      end
    end

    context 'when the database connection fails' do
      before do
        allow(ActiveRecord::Base).to receive(:connection).and_raise(StandardError)
      end

      it 'returns a :service_unavailable status' do
        result = described_class.readiness_probe
        expect(result[:status]).to eq(:service_unavailable)
      end
    end
  end

  describe '.health_probe' do
    let(:db_connection) { double('db_connection', execute: true) }
    let(:redis_client) { double('redis_client', ping: 'PONG') }

    before do
      allow(ActiveRecord::Base).to receive(:connection).and_return(db_connection)
      allow(Redis).to receive(:with).and_yield(redis_client)
    end

    context 'when all components are healthy' do
      it 'returns an :ok status and success details' do
        result = described_class.health_probe

        expect(result[:status]).to eq(:ok)
        expect(result[:message]).to eq('Application is healthy')
        expect(result[:details]).to eq({ database: true, redis: true })
      end
    end

    context 'when the database check fails' do
      before do
        allow(db_connection).to receive(:execute).and_raise(StandardError, 'DB is down')
      end

      it 'returns a :service_unavailable status with correct details' do
        result = described_class.health_probe

        expect(result[:status]).to eq(:service_unavailable)
        expect(result[:errors].first).to include('Database check failed: DB is down')
        expect(result[:details]).to eq({ database: false, redis: true })
      end
    end

    context 'when the Redis check fails' do
      before do
        allow(redis_client).to receive(:ping).and_raise(Redis::CannotConnectError, 'Redis is unavailable')
      end

      it 'returns a :service_unavailable status with correct details' do
        result = described_class.health_probe

        expect(result[:status]).to eq(:service_unavailable)
        expect(result[:errors].first).to include('Redis check failed: Redis is unavailable')
        expect(result[:details]).to eq({ database: true, redis: false })
      end
    end

    context 'when both checks fail' do
      before do
        allow(db_connection).to receive(:execute).and_raise(StandardError, 'DB error')
        allow(redis_client).to receive(:ping).and_raise(Redis::CannotConnectError, 'Redis error')
      end

      it 'returns a :service_unavailable status with all errors' do
        result = described_class.health_probe

        expect(result[:status]).to eq(:service_unavailable)
        expect(result[:errors]).to contain_exactly(
          'Database check failed: DB error',
          'Redis check failed: Redis error'
        )
        expect(result[:details]).to eq({ database: false, redis: false })
      end
    end
  end
end
