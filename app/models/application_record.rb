# frozen_string_literal: true

# Base class for all models in BY project
class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true
end
