# frozen_string_literal: true

require 'deployment_helpers'

unless DeploymentHelpers.assets_compilation?
  # This module contains constants related to the site.
  module SiteConstants
    OUR_PUBLISHER = 'פרויקט בן-יהודה'
    OUR_PLACE_OF_PUBLICATION = 'benyehuda.org'
    TAGGING_POLICY_URL = 'https://benyehuda.org/page/tagging'
    YOUTUBE_CHANNEL_ID = 'UClsusG2EWu45WZ-yNJsdFAw' # Ben-Yehuda YouTube channel ID

    APP_HOSTNAME = ENV.fetch('APP_HOSTNAME', 'benyehuda.org')

    TASK_SYSTEM_HOST = ENV.fetch('TASK_SYSTEM_HOST')
    TASK_SYSTEM_PORT = Integer(ENV.fetch('TASK_SYSTEM_PORT'))
    TASK_SYSTEM_URL = "#{TASK_SYSTEM_PORT == 443 ? 'https' : 'http'}://#{TASK_SYSTEM_HOST}" \
                      "#{":#{TASK_SYSTEM_PORT}" unless TASK_SYSTEM_PORT == 80}".freeze

    # TODO: to be removed after we get rid of HtmlFiles
    BASE_DIR = ENV.fetch('BASE_DIR')
  end
end
