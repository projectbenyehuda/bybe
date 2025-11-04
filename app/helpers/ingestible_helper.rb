# frozen_string_literal: true

module IngestibleHelper
  def title_from_prospective_volume_id(prospective_volume_id, ptitle)
    return ptitle if ptitle.present?
    return nil if prospective_volume_id.nil?

    unless prospective_volume_id[0] == 'P'
      c = Collection.find(prospective_volume_id)
      return c.title_and_authors if c.present?
    end
    pub = Publication.find(prospective_volume_id[1..])
    return "#{pub.authority.name} – #{pub.title} (#{t(:new)}!)"
  end

  def cell_style(found_in_markdown, included)
    case [found_in_markdown, included]
    when [true, 'yes']
      'lgreenbg'
    when [false, 'yes']
      'lredbg'
    when [true, 'no']
      'lredbg'
    else
      ''
    end
  end

  def copyrighted_ip_options
    Ingestible::COPYRIGHTED_IP_OPTIONS.map do |code|
      [textify_intellectual_property(code), code]
    end
  end

  def authorities_including_implicit(toc_text)
    # Merge per role: specific authorities override defaults for their role only
    aus = merge_authorities_per_role_helper(toc_text, @ingestible.default_authorities)

    if aus.present?
      return aus.map do |ia|
               "#{ia['authority_name'].presence || ia['new_person']} (#{textify_authority_role(ia['role'])})"
             end.join('<br />')
    end

    return t(:unknown)
  end

  private

  # Same logic as in controller but for helper
  def merge_authorities_per_role_helper(work_authorities, default_authorities)
    # Handle explicit empty array - no defaults should apply
    return [] if work_authorities == '[]'

    work_auths = work_authorities.present? ? JSON.parse(work_authorities) : []
    default_auths = default_authorities.present? ? JSON.parse(default_authorities) : []

    # If no defaults, just return work authorities
    return work_auths if default_auths.empty?

    # Get roles present in work authorities
    work_roles = work_auths.pluck('role').uniq

    # Start with work authorities, then add defaults for roles not present in work authorities
    result = work_auths.dup
    default_auths.each do |default_auth|
      unless work_roles.include?(default_auth['role'])
        result << default_auth
      end
    end

    result
  end
end
