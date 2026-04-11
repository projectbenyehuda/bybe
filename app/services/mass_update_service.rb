# frozen_string_literal: true

# Applies a batch of changes to a list of Manifestation and/or Collection records.
#
# Usage:
#   results = MassUpdateService.new(records, changes).apply
#
# records: array of { 'type' => 'Manifestation'|'Collection', 'id' => Integer }
# changes: array of change hashes (see CHANGE_KINDS below)
#
# Returns:
#   { [type, id] => [ :ok | error_string, ... ] }  (one entry per change per record)
class MassUpdateService
  CHANGE_KINDS = %w(field_update involved_authority_add involved_authority_remove
                    external_link_add external_link_remove).freeze

  MANIFESTATION_FIELDS = %w(title alternate_titles sort_title status comment
                            exclude_from_index sefaria_linker).freeze
  EXPRESSION_FIELDS    = %w(title date period language first_publication_date
                            source_edition comment intellectual_property).freeze
  WORK_FIELDS          = %w(title genre primary orig_lang origlang_title date comment).freeze
  COLLECTION_FIELDS    = %w(title sort_title collection_type comment
                            suppress_download_and_print).freeze

  def initialize(records, changes)
    @records = records
    @changes = changes
  end

  def apply
    results = {}
    @records.each do |rec|
      key = [rec['type'], rec['id'].to_i]
      record = load_record(rec['type'], rec['id'].to_i)
      results[key] = if record.nil?
                       @changes.map { I18n.t('admin.mass_update.errors.record_not_found') }
                     else
                       @changes.map.with_index { |change, i| apply_change(record, change, i) }
                     end
    end
    results
  end

  private

  def load_record(type, id)
    case type
    when 'Manifestation' then Manifestation.find_by(id: id)
    when 'Collection'    then Collection.find_by(id: id)
    end
  end

  def apply_change(record, change, _index)
    case change['kind']
    when 'field_update'           then apply_field_update(record, change)
    when 'involved_authority_add' then apply_involved_authority(record, change, :add)
    when 'involved_authority_remove' then apply_involved_authority(record, change, :remove)
    when 'external_link_add'      then apply_external_link(record, change, :add)
    when 'external_link_remove'   then apply_external_link(record, change, :remove)
    else
      I18n.t('admin.mass_update.errors.unknown_change_kind', kind: change['kind'])
    end
  rescue StandardError => e
    error_id = SecureRandom.hex(4)
    Rails.logger.error("[MassUpdateService] Unexpected error (#{error_id}): #{e.message}\n" \
                       "#{e.backtrace.first(10).join("\n")}")
    I18n.t('admin.mass_update.errors.unknown_error', error_id: error_id)
  end

  # --- Field update ---

  def apply_field_update(record, change)
    record_type = change['record_type']
    field       = change['field']
    value       = change['value'].presence

    target = resolve_field_target(record, record_type)
    if target.nil?
      return I18n.t('admin.mass_update.errors.field_not_applicable',
                    record_type: record_type, field: field)
    end

    unless allowed_field?(record_type, field)
      return I18n.t('admin.mass_update.errors.field_not_allowed', field: field)
    end

    target.assign_attributes(field => value)
    if target.save
      verify_field_persisted(target, field, value)
    else
      target.errors.full_messages.join(', ')
    end
  end

  # Guards against silent normalization: if a before_validation callback
  # reset the value to something other than what we intended, report it.
  def verify_field_persisted(target, field, intended_value)
    actual = target.public_send(field)
    if intended_value.nil?
      actual.nil? ? :ok : I18n.t('admin.mass_update.errors.value_not_persisted', field: field)
    elsif actual.to_s == intended_value.to_s
      :ok
    else
      I18n.t('admin.mass_update.errors.value_not_persisted', field: field)
    end
  end

  # Returns the AR object that owns the given record_type fields for this record.
  def resolve_field_target(record, record_type)
    case record
    when Manifestation
      case record_type
      when 'manifestation' then record
      when 'expression'    then record.expression
      when 'work'          then record.expression&.work
      end
    when Collection
      record_type == 'collection' ? record : nil
    end
  end

  def allowed_field?(record_type, field)
    case record_type
    when 'manifestation' then MANIFESTATION_FIELDS.include?(field)
    when 'expression'    then EXPRESSION_FIELDS.include?(field)
    when 'work'          then WORK_FIELDS.include?(field)
    when 'collection'    then COLLECTION_FIELDS.include?(field)
    else false
    end
  end

  # --- InvolvedAuthority ---

  def apply_involved_authority(record, change, action)
    authority = Authority.find_by(id: change['authority_id'])
    return I18n.t('admin.mass_update.errors.authority_not_found') if authority.nil?

    entity = resolve_ia_entity(record, change['entity'])
    if entity.nil?
      return I18n.t('admin.mass_update.errors.ia_entity_not_applicable',
                    entity: change['entity'])
    end

    role = change['role']

    if action == :add
      ia = InvolvedAuthority.find_or_initialize_by(item: entity, authority: authority, role: role)
      ia.save ? :ok : ia.errors.full_messages.join(', ')
    else
      ia = InvolvedAuthority.find_by(item: entity, authority: authority, role: role)
      if ia
        ia.destroy
        ia.destroyed? ? :ok : I18n.t('admin.mass_update.errors.destroy_failed')
      else
        I18n.t('admin.mass_update.errors.ia_not_found')
      end
    end
  end

  def resolve_ia_entity(record, entity_type)
    case record
    when Manifestation
      case entity_type
      when 'work'       then record.expression&.work
      when 'expression' then record.expression
      end
    when Collection
      entity_type == 'collection' ? record : nil
    end
  end

  # --- ExternalLink ---

  def apply_external_link(record, change, action)
    if action == :add
      link = ExternalLink.new(
        linkable: record,
        url: change['url'],
        linktype: change['linktype'],
        description: change['description'],
        status: :approved
      )
      link.save ? :ok : link.errors.full_messages.join(', ')
    else
      link = ExternalLink.find_by(linkable: record, url: change['url'])
      if link
        link.destroy
        link.destroyed? ? :ok : I18n.t('admin.mass_update.errors.destroy_failed')
      else
        I18n.t('admin.mass_update.errors.external_link_not_found', url: change['url'])
      end
    end
  end
end
