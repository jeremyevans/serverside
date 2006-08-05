# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/switchtower.rake, and they will automatically be available to Rake.

require(File.join(File.dirname(__FILE__), 'config', 'boot'))

require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'

##############################################################################
# Testing
##############################################################################

TEST_CHANGES_SINCE = Time.now - 600

# Look up tests for recently modified sources.
def recent_tests(source_pattern, test_path, touched_since = 10.minutes.ago)
  FileList[source_pattern].map do |path|
    if File.mtime(path) > touched_since
      test = "#{test_path}/#{File.basename(path, '.rb')}_test.rb"
      test if File.exists?(test)
    end
  end.compact
end


# Recreated here from ActiveSupport because :uncommitted needs it before Rails is available
module Kernel
  def silence_stderr
    old_stderr = STDERR.dup
    STDERR.reopen(RUBY_PLATFORM =~ /mswin/ ? 'NUL:' : '/dev/null')
    STDERR.sync = true
    yield
  ensure
    STDERR.reopen(old_stderr)
  end
end

desc 'Test all units and functionals'
task :test do
  Rake::Task['test_units'].invoke       rescue got_error = true
  Rake::Task['test_functionals'].invoke rescue got_error = true

  raise 'Test failures' if got_error
end

desc 'Test recent changes'
Rake::TestTask.new('test_recent') do |t|
  since = TEST_CHANGES_SINCE
  touched = FileList['test/**/*_test.rb'].select { |path| File.mtime(path) > since } +
    recent_tests('app/models/*.rb', 'test/unit', since) +
    recent_tests('app/controllers/*.rb', 'test/functional', since)

  t.libs << 'test'
  t.verbose = true
  t.test_files = touched.uniq
end
  
desc 'Test changes since last checkin (only Subversion)'
Rake::TestTask.new('test_uncommitted') do |t|
  changed_since_checkin = silence_stderr { `svn status` }.map { |path| path.chomp[7 .. -1] }
  models = changed_since_checkin.select { |path| path =~ /app\/models\/.*\.rb/ }
  tests = models.map { |model| "test/unit/#{File.basename(model, '.rb')}_test.rb" }

  t.libs << 'test'
  t.verbose = true
  t.test_files = tests.uniq
end

desc 'Run the unit tests in test/unit'
Rake::TestTask.new('test_units') do |t|
  t.libs << 'test'
  t.pattern = 'test/unit/**/*_test.rb'
  t.verbose = true
end

desc 'Run the functional tests in test/functional'
Rake::TestTask.new('test_functionals') do |t|
  t.libs << 'test'
  t.pattern = 'test/functional/**/*_test.rb'
  t.verbose = true
end

##############################################################################
# Statistics
##############################################################################

STATS_DIRECTORIES = [
  %w(Controllers        app/controllers), 
  %w(Unit\ tests        test/unit),
  %w(Functional\ tests  test/functional),
  %w(Libraries          lib),
  %w(Models             app/models)
].collect { |name, dir| [ name, "#{APP_ROOT}/#{dir}" ] }.select { |name, dir| File.directory?(dir) }

desc "Report code statistics (LOCs, etc) from the application"
task :stats do
  require 'extras/stats'
  verbose = true
  CodeStatistics.new(*STATS_DIRECTORIES).to_s
end

##############################################################################
# SVN
##############################################################################

desc "Add new files to subversion"
task :svn_add do
   system "svn status | grep '^\?' | sed -e 's/? *//' | sed -e 's/ /\ /g' | xargs svn add"
end

##############################################################################
# Documentation
##############################################################################

desc "Generate documentation for the application"
Rake::RDocTask.new("doc") do |rdoc|
  rdoc.rdoc_dir = 'doc/app'
  rdoc.title    = "Reality Documentation"
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('doc/README') if File.file?('doc/README')
  rdoc.rdoc_files.include('app/**/*.rb')
end

##############################################################################
# Deployment
##############################################################################
