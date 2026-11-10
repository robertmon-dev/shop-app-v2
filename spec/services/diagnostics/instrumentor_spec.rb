# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Services::Instrumentor, type: :service do
  subject(:instrumentor) { described_class }

  let(:registry_double) { instance_double('Prometheus::Client::Registry', counter: nil, gauge: nil, get: nil) }

  before do
    stub_const('Prometheus::Client', class_double('Prometheus::Client', registry: registry_double))
    instrumentor.instance_variable_set(:@registry, nil)
  end

  describe '.initialize_metrics' do
    it 'creates the diagnostics_checks_total counter' do
      instrumentor.initialize_metrics
      expect(registry_double).to have_received(:counter).with(
        :diagnostics_checks_total,
        docstring: 'Diagnostics total score',
        labels: [:check_type]
      )
    end

    it 'creates the diagnostics_component_up gauge' do
      instrumentor.initialize_metrics
      expect(registry_double).to have_received(:gauge).with(
        :diagnostics_component_up,
        docstring: 'Components status',
        labels: [:component]
      )
    end

    it 'creates the diagnostics_component_errors_total counter' do
      instrumentor.initialize_metrics
      expect(registry_double).to have_received(:counter).with(
        :diagnostics_component_errors_total,
        docstring: 'Error per component',
        labels: [:component]
      )
    end

    it 'assigns the registry' do
      instrumentor.initialize_metrics
      expect(instrumentor.registry).to eq(registry_double)
    end
  end

  describe 'with initialized metrics' do
    let(:checks_counter) { instance_double('Prometheus::Client::Counter', increment: nil) }
    let(:component_gauge) { instance_double('Prometheus::Client::Gauge', set: nil) }
    let(:errors_counter) { instance_double('Prometheus::Client::Counter', increment: nil) }

    before do
      instrumentor.initialize_metrics
      allow(registry_double).to receive(:get).with(:diagnostics_checks_total).and_return(checks_counter)
      allow(registry_double).to receive(:get).with(:diagnostics_component_up).and_return(component_gauge)
      allow(registry_double).to receive(:get).with(:diagnostics_component_errors_total).and_return(errors_counter)
    end

    describe '.check_performed' do
      it 'increments the diagnostics_checks_total counter' do
        instrumentor.check_performed(:readiness)
        expect(checks_counter).to have_received(:increment).with(labels: { check_type: :readiness })
      end

      it 'does not raise an error if the registry is not set' do
        instrumentor.instance_variable_set(:@registry, nil)
        expect { instrumentor.check_performed(:health) }.not_to raise_error
      end
    end

    describe '.report_component_status' do
      context 'when a component is up' do
        it 'sets the component_up gauge to 1' do
          instrumentor.report_component_status(:database, is_up: true)
          expect(component_gauge).to have_received(:set).with(1, labels: { component: :database })
        end

        it 'does not increment the error counter' do
          instrumentor.report_component_status(:database, is_up: true)
          expect(errors_counter).not_to have_received(:increment)
        end
      end

      context 'when a component is down with an error' do
        it 'sets the component_up gauge to 0' do
          instrumentor.report_component_status(:redis, is_up: false, error: true)
          expect(component_gauge).to have_received(:set).with(0, labels: { component: :redis })
        end

        it 'increments the component_errors_total counter' do
          instrumentor.report_component_status(:redis, is_up: false, error: true)
          expect(errors_counter).to have_received(:increment).with(labels: { component: :redis })
        end
      end

      it 'does not raise an error if the registry is not set' do
        instrumentor.instance_variable_set(:@registry, nil)
        expect { instrumentor.report_component_status(:database, is_up: false) }.not_to raise_error
      end
    end
  end
end
