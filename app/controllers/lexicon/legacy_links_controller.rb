# frozen_string_literal: true

module Lexicon
  # Controller to handle legacy links
  # It checks if we have a legacy link record matching requested url
  # If we have, it redirects to the corresponding LexEntry attachment
  class LegacyLinksController < ApplicationController
    def open_legacy_link
      old_path = params[:old_path]

      link = LexLegacyLink.find_by(old_path: old_path)

      if link
        redirect_to link.new_path
      else
        render file: Rails.public_path.join('404.html'), status: :not_found, layout: false
      end
    end
  end
end
