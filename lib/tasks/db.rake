namespace :db do

  desc "Clones database from another branch as specified by `SOURCE_BRANCH` and `TARGET_BRANCH` env params."
  task :clone_from_branch do

    abort "You need to provide a SOURCE_BRANCH to clone from as an environment variable." if ENV['SOURCE_BRANCH'].blank?
    abort "You need to provide a TARGET_BRANCH to clone to as an environment variable."   if ENV['TARGET_BRANCH'].blank?

    database_configuration = Rails.configuration.database_configuration[Rails.env]
    current_database_name = database_configuration["database"]

    source_db = current_database_name.sub(CURRENT_BRANCH, ENV['SOURCE_BRANCH'])
    target_db = current_database_name.sub(CURRENT_BRANCH, ENV['TARGET_BRANCH'])

    mysql_opts =  "-u #{database_configuration['username']} "
    mysql_opts << "--password=\"#{database_configuration['password']}\" " if database_configuration['password'].presence

    `mysqlshow #{mysql_opts} | grep "#{source_db}"`
    raise "Source database #{source_db} not found" if $?.to_i != 0

    `mysqlshow #{mysql_opts} | grep "#{target_db}"`
    raise "Target database #{target_db} already exists" if $?.to_i == 0

    puts "Creating empty database #{target_db}"
    `mysql #{mysql_opts} -e "CREATE DATABASE #{target_db}"`

    puts "Copying #{source_db} into #{target_db}"
    `mysqldump #{mysql_opts} #{source_db} | mysql #{mysql_opts} #{target_db}`

  end

end
