# frozen_string_literal: true

desc 'Recalculate intellectual property for all expressions based on involved authorities'
task recalculate_intellectual_property: :environment do
  puts 'Recalculating intellectual property for all expressions...'
  puts ''

  total = Expression.count
  updated = 0
  skipped = 0
  
  Expression.find_each.with_index do |expression, index|
    # Get all involved authorities for this expression
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
