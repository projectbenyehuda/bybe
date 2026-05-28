# frozen_string_literal: true

# Wrap every Sidekiq job in Chewy.strategy(:bypass) so that Chewy
# index-update callbacks (triggered e.g. by ActiveStorage::AnalyzeJob)
# silently no-op instead of raising Chewy::UndefinedUpdateStrategy.
# Jobs that need Elasticsearch indexing (e.g. Lexicon::IngestFile) push
# :atomic on top of this inside their own perform method.
class ChewyBypassMiddleware
  def call(_worker, _job, _queue, &)
    Chewy.strategy(:bypass, &)
  end
end

Sidekiq.configure_server do |config|
  config.logger = Sidekiq::Logger.new($stdout)
  config.server_middleware do |chain|
    chain.add ChewyBypassMiddleware
  end
end
