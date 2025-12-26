# frozen_string_literal: true

module Lexicon
  # Helper methods for verification workbench views
  module VerificationHelper
    def badge_class_for_status(status)
      case status.to_sym
      when :draft then 'bg-secondary'
      when :verifying then 'bg-warning text-dark'
      when :verified then 'bg-success'
      when :error then 'bg-danger'
      when :published then 'bg-primary'
      else 'bg-light text-dark'
      end
    end
  end
end
