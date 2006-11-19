require 'rake'
require 'rake/clean'
require 'rake/gempackagetask'
require 'rake/rdoctask'
require 'fileutils'
include FileUtils

NAME = "serverside"
VERS = "0.2.9"
CLEAN.include ['**/.*.sw?', 'pkg/*', '.config', 'doc/*', 'coverage/*']
RDOC_OPTS = ['--quiet', '--title', "ServerSide Documentation",
  "--opname", "index.html",
  "--line-numbers", 
  "--main", "README",
  "--inline-source"]

desc "Packages up ServerSide."
task :default => [:package]
task :package => [:clean]

task :doc => [:rdoc]

Rake::RDocTask.new do |rdoc|
  rdoc.rdoc_dir = 'doc/rdoc'
  rdoc.options += RDOC_OPTS
  rdoc.main = "README"
  rdoc.title = "ServerSide Documentation"
  rdoc.rdoc_files.add ['README', 'CHANGELOG', 'COPYING', 'lib/serverside.rb', 'lib/serverside/*.rb']
end

spec = Gem::Specification.new do |s|
  s.name = NAME
  s.version = VERS
  s.platform = Gem::Platform::RUBY
  s.has_rdoc = true
  s.extra_rdoc_files = ["README", "CHANGELOG", "COPYING"]
  s.rdoc_options += RDOC_OPTS + 
    ['--exclude', '^(examples|extras)\/', '--exclude', 'lib/serverside.rb']
  s.summary = "Performance-oriented web framework."
  s.description = s.summary
  s.author = "Sharon Rosner"
  s.email = 'ciconia@gmail.com'
  s.homepage = 'http://code.google.com/p/serverside/'
  s.executables = ['serverside']

  s.add_dependency('metaid')
  s.required_ruby_version = '>= 1.8.2'

  s.files = %w(COPYING README Rakefile) + Dir.glob("{bin,doc,spec,lib}/**/*") 
      
  s.require_path = "lib"
  s.bindir = "bin"
end

Rake::GemPackageTask.new(spec) do |p|
  p.need_tar = true
  p.gem_spec = spec
end

task :install do
  sh %{rake package}
  sh %{sudo gem install pkg/#{NAME}-#{VERS}}
end

task :uninstall => [:clean] do
  sh %{sudo gem uninstall #{NAME}}
end

desc 'Update docs and upload to rubyforge.org'
task :doc_rforge do
  sh %{rake doc}
  sh %{scp -r doc/* ciconia@rubyforge.org:/var/www/gforge-projects/serverside}
end

require 'spec/rake/spectask'

desc "Run specs with coverage"
Spec::Rake::SpecTask.new('spec') do |t|
  t.spec_files = FileList['spec/*_spec.rb']
  t.rcov = true
end

#require 'spec/rake/rcov_verify'

#RCov::VerifyTask.new(:rcov_verify => :rcov) do |t|
#  t.threshold = 95.4 # Make sure you have rcov 0.7 or higher!
#  t.index_html = 'coverage/index.html'
#end

##############################################################################
# Statistics
##############################################################################

STATS_DIRECTORIES = [
  %w(Code                 lib/),
  %w(Specification\ tests spec)
].collect { |name, dir| [ name, "./#{dir}" ] }.select { |name, dir| File.directory?(dir) }

desc "Report code statistics (KLOCs, etc) from the application"
task :stats do
  require 'extra/stats'
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

