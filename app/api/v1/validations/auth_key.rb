# frozen_string_literal: true

module V1
  module Validations
    # Auth key check
    class AuthKey < Grape::Validations::Validators::Base
      class AuthFailed < StandardError; end

      def validate_param!(attr_name, params)
        key = params[attr_name]
        api_key = ApiKey.find_by(key: key) if key.present?
        if api_key.nil? || api_key.status_disabled?
          raise AuthFailed, "#{@scope.full_name(attr_name)} not found or disabled"
        end

        record_usage(api_key)
      end

      private

      # Single atomic UPDATE: no read-modify-write race between concurrent calls, and no
      # callbacks or updated_at churn
      def record_usage(api_key)
        ApiKey.where(id: api_key.id).update_all(['calls_count = calls_count + 1, last_used_at = ?', Time.current])
      end
    end
  end
end
