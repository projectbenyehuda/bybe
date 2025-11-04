# frozen_string_literal: true

desc 'Recalculate intellectual property for all expressions based on involved authorities'
task recalculate_intellectual_property: :environment do
  puts 'Recalculating intellectual property for all expressions...'
  puts ''

  total = Expression.count
  updated = 0
  skipped = 0
  
  # Preload associations to avoid N+1 queries
  Expression.includes(work: :involved_authorities, involved_authorities: []).find_each.with_index do |expression, index|
    # Skip if current state is 'orphan' - that was set manually and can't be calculated
    if expression.intellectual_property_orphan?
      skipped += 1
      next
    end

    # Get all involved authorities for this expression
    # Note: authority_id is a foreign key, so accessing it doesn't trigger queries
    work_authority_ids = expression.work.involved_authorities.map(&:authority_id)
    expression_authority_ids = expression.involved_authorities.map(&:authority_id)
    authority_ids = (work_authority_ids + expression_authority_ids).uniq

    # Compute intellectual property
    computed_ip = ComputeIntellectualProperty.call(authority_ids)

    # Update if different
    if expression.intellectual_property != computed_ip.to_s
      old_value = expression.intellectual_property
      expression.update_column(:intellectual_property, Expression.intellectual_properties[computed_ip])
      puts "Expression #{expression.id}: #{old_value} → #{computed_ip}"
      updated += 1
    else
      skipped += 1
    end

    # Progress indicator
    if (index + 1) % 100 == 0
      puts "Processed #{index + 1}/#{total} expressions (#{updated} updated, #{skipped} skipped)"
    end
  end

  puts ''
  puts '=' * 80
  puts 'SUMMARY'
  puts '=' * 80
  puts "Total expressions: #{total}"
  puts "Updated: #{updated}"
  puts "Skipped (already correct): #{skipped}"
  puts '=' * 80
end
