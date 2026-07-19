# frozen_string_literal: true

# monkey-patching AnalyzeJob to wrap perform with Chewy startegy.
# It is required as we may analyze attachments in Chewy-indexed models (e.g. Manifestation)
Rails.application.config.after_initialize do
  ActiveStorage::AnalyzeJob.around_perform do |_job, block|
    # we use bypass strategy as we don't need to index with Chewy any analyzed data
    Chewy.strategy(:bypass) do
      block.call
    end
  end
end