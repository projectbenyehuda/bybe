namespace :git do

  desc "Create a branch off the current branch and clone the current branch's database."
  task :branch do 
    print 'New Branch Name: '
    new_branch_name = STDIN.gets.strip 

    CURRENT_BRANCH = `git status | head -1`.to_s.gsub('On branch ','').chomp

    say "Creating new branch and checking it out..."
    sh "git co -b #{new_branch_name}"

    say "Cloning database from #{CURRENT_BRANCH}..."

    ENV['SOURCE_BRANCH'] = CURRENT_BRANCH # Set source to be the current branch for clone_from_branch task.
    ENV['TARGET_BRANCH'] = new_branch_name
    Rake::Task['db:clone_from_branch'].invoke

    say "All done!"
  end

end
