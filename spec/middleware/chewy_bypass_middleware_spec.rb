# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ChewyBypassMiddleware do
  subject(:middleware) { described_class.new }

  describe '#call' do
    it 'wraps the job block in Chewy.strategy(:bypass)' do
      strategy_inside_job = nil
      middleware.call(nil, nil, nil) do
        strategy_inside_job = Chewy.strategy.current.name
      end
      expect(strategy_inside_job).to eq(:bypass)
    end

    it 'does not raise UndefinedUpdateStrategy even when root_strategy is :base' do
      original_root = Chewy.root_strategy
      Chewy.root_strategy = :base
      Chewy.current.delete(:chewy_strategy)

      expect do
        middleware.call(nil, nil, nil) do
          Chewy.strategy.current.update(ManifestationsIndex, [], {})
        end
      end.not_to raise_error
    ensure
      Chewy.root_strategy = original_root
      Chewy.current.delete(:chewy_strategy)
    end

    it 'allows :atomic to override bypass inside the job' do
      strategy_inside_atomic = nil
      middleware.call(nil, nil, nil) do
        Chewy.strategy(:atomic) do
          strategy_inside_atomic = Chewy.strategy.current.name
        end
      end
      expect(strategy_inside_atomic).to eq(:atomic)
    end

    it 'restores prior strategy after job completes' do
      outer_strategy_before = Chewy.strategy.current.name
      middleware.call(nil, nil, nil) { nil }
      expect(Chewy.strategy.current.name).to eq(outer_strategy_before)
    end
  end
end
