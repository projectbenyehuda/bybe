# frozen_string_literal: true

require 'sidekiq/api'

# Sidekiq job to generate KWIC concordance asynchronously for Authority and Collection entities
# This is used for larger entities where concordance generation may take a long time
class GenerateKwicConcordanceJob
  include Sidekiq::Job
  include BybeUtils

  # Check if a job for this entity is already queued or running
  # @param entity_type [String] The entity type: 'Authority' or 'Collection'
  # @param entity_id [Integer] The ID of the entity
  # @return [Boolean] true if a job is already in progress, false otherwise
  def self.in_progress?(entity_type, entity_id)
    # In test mode with fake jobs, check the jobs array
    # Note: inline mode executes jobs immediately, so there's no queueing issue
    # We need to check if Sidekiq::Testing is defined because it's only loaded in test environment
    if defined?(Sidekiq::Testing) && Sidekiq::Testing.fake?
      return jobs.any? do |job|
        job['args'][0] == entity_type && job['args'][1] == entity_id
      end
    end

    # Check queued jobs (not yet started)
    # Using any? for efficient early termination
    queue = Sidekiq::Queue.new
    queued = queue.any? do |job|
      job.klass == 'GenerateKwicConcordanceJob' &&
        job.args[0] == entity_type &&
        job.args[1] == entity_id
    end

    return true if queued

    # Check currently running jobs
    workers = Sidekiq::Workers.new
    workers.any? do |_process_id, _thread_id, work|
      # Use dig to safely access nested hash values
      work.dig('payload', 'class') == 'GenerateKwicConcordanceJob' &&
        work.dig('payload', 'args', 0) == entity_type &&
        work.dig('payload', 'args', 1) == entity_id
    end
  end

  # @param entity_type [String] The entity type: 'Authority' or 'Collection'
  # @param entity_id [Integer] The ID of the entity
  def perform(entity_type, entity_id)
    entity = entity_type.constantize.find(entity_id)

    case entity_type
    when 'Collection'
      generate_collection_concordance(entity)
    when 'Authority'
      generate_authority_concordance(entity)
    else
      raise ArgumentError, "Unsupported entity type: #{entity_type}"
    end
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error("GenerateKwicConcordanceJob: #{entity_type} with id #{entity_id} not found: #{e.message}")
  rescue StandardError => e
    Rails.logger.error("GenerateKwicConcordanceJob failed for #{entity_type} #{entity_id}: #{e.message}")
    raise e
  end

  private

  def generate_collection_concordance(collection)
    labelled_texts = []
    collection.flatten_items.each do |ci|
      next if ci.item.nil? || ci.item_type != 'Manifestation'

      labelled_texts << {
        label: ci.title,
        buffer: ci.item.to_plaintext
      }
    end

    kwic_text = GenerateKwicConcordance.call(labelled_texts)
    filename = "#{collection.title.gsub(/[^0-9א-תA-Za-z.\-]/, '_')}.kwic"
    austr = textify_authorities_and_roles(collection.involved_authorities)
    MakeFreshDownloadable.call('kwic', filename, '', collection, austr, kwic_text: kwic_text)
  end

  def generate_authority_concordance(authority)
    labelled_texts = authority.published_manifestations(:author, :translator).map do |m|
      {
        label: m.title,
        buffer: m.to_plaintext
      }
    end

    kwic_text = GenerateKwicConcordance.call(labelled_texts)
    filename = "#{authority.name.gsub(/[^0-9א-תA-Za-z.\-]/, '_')}.kwic"
    austr = authority.name
    MakeFreshDownloadable.call('kwic', filename, '', authority, austr, kwic_text: kwic_text)
  end
end
