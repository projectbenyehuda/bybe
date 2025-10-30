# frozen_string_literal: true

desc 'Transition authorities and manifestations to public domain based on copyright expiration (death + 71 years)'
task :copyright_expiration, %i[execute output] => :environment do |_task, args|
  # Default to dry-run mode unless --execute is passed
  execute_mode = args[:execute] == 'execute'
  # Allow output redirection for testing (defaults to $stdout)
  output = args[:output] || $stdout

  if execute_mode
    output.puts 'Running in EXECUTE mode - changes will be saved to database'
  else
    output.puts 'Running in DRY-RUN mode - no changes will be saved'
    output.puts 'To execute changes, run: rake copyright_expiration[execute]'
  end
  output.puts ''

  # Calculate the target year (71 years ago from current year)
  current_year = Time.zone.today.year
  target_year = current_year - 71

  output.puts "Processing authorities who died in #{target_year} (#{current_year} - 71 years)..."
  output.puts ''

  # Statistics
  stats = {
    authorities_checked: 0,
    authorities_updated: 0,
    manifestations_checked: 0,
    manifestations_updated: 0
  }

  # Find all people who died in the target year and are not yet public domain
  Person.find_each do |person|
    next if person.authority.nil?
    next if person.deathdate.blank?

    death_year = person.death_year.to_i
    next if death_year == 0 || death_year != target_year

    authority = person.authority
    stats[:authorities_checked] += 1

    # Skip if already public domain
    if authority.intellectual_property_public_domain?
      output.puts "Authority '#{authority.name}' (ID: #{authority.id}) - already public_domain, skipping"
      next
    end

    output.puts "Authority '#{authority.name}' (ID: #{authority.id}) - died in #{death_year}"
    output.puts "  Current status: #{authority.intellectual_property}"
    output.puts '  Updating to: public_domain'

    if execute_mode
      Chewy.strategy(:atomic) do
        authority.update!(intellectual_property: :public_domain)
      end
      stats[:authorities_updated] += 1
      output.puts '  ✓ Updated'
    else
      stats[:authorities_updated] += 1
      output.puts '  [DRY-RUN] Would update'
    end

    # Now check manifestations involving this authority
    manifestations = authority.manifestations

    manifestations.each do |manifestation|
      stats[:manifestations_checked] += 1

      # Skip if manifestation is not published
      next unless manifestation.published?

      # Get all involved authorities for this manifestation
      involved_authorities = manifestation.involved_authorities.map(&:authority).uniq

      # Check if all involved authorities are public_domain
      all_public_domain = involved_authorities.all? do |auth|
        # In execute mode, we already updated the current authority, so check it separately
        if execute_mode && auth.id == authority.id
          true # We just updated it
        elsif !execute_mode && auth.id == authority.id
          true # In dry-run, assume this authority would be updated
        else
          auth.intellectual_property_public_domain?
        end
      end

      # Only update if all authorities are public_domain
      next unless all_public_domain

      expression = manifestation.expression

      # Check if expression needs updating
      next if expression.intellectual_property_public_domain?

      output.puts "  Manifestation '#{manifestation.title}' (ID: #{manifestation.id})"
      output.puts "    Expression (ID: #{expression.id}) current status: #{expression.intellectual_property}"
      output.puts '    Updating expression to: public_domain'

      if execute_mode
        Chewy.strategy(:atomic) do
          expression.update!(intellectual_property: :public_domain)
        end
        stats[:manifestations_updated] += 1
        output.puts '    ✓ Updated'
      else
        stats[:manifestations_updated] += 1
        output.puts '    [DRY-RUN] Would update'
      end
    end

    output.puts ''
  end

  # Print summary
  output.puts '=' * 80
  output.puts 'SUMMARY'
  output.puts '=' * 80
  output.puts "Mode: #{execute_mode ? 'EXECUTE' : 'DRY-RUN'}"
  output.puts "Target year: #{target_year}"
  output.puts ''
  output.puts 'Authorities:'
  output.puts "  Checked: #{stats[:authorities_checked]}"
  output.puts "  #{execute_mode ? 'Updated' : 'Would update'}: #{stats[:authorities_updated]}"
  output.puts ''
  output.puts 'Manifestations:'
  output.puts "  Checked: #{stats[:manifestations_checked]}"
  output.puts "  #{execute_mode ? 'Updated' : 'Would update'}: #{stats[:manifestations_updated]}"
  output.puts '=' * 80

  unless execute_mode
    output.puts ''
    output.puts 'This was a dry-run. To apply changes, run:'
    output.puts '  rake copyright_expiration[execute]'
  end
end
