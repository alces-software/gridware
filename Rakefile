
require 'rake/testtask'

Rake::TestTask.new do |t|
  # Set up ruby environment - duplicated from libexec/actions/gridware
  ####
  ENV['cw_ROOT'] = '/opt/clusterware'

  v = `source #{ENV['cw_ROOT']}/etc/gridware.rc 2> /dev/null && echo ${cw_GRIDWARE_root}`.chomp
  ENV['cw_GRIDWARE_root'] = v unless v.empty?

  ENV['ALCES_CONFIG_PATH'] ||= "#{ENV['cw_GRIDWARE_root']}/etc:#{ENV['cw_ROOT']}/etc"
  ENV['BUNDLE_GEMFILE'] ||= "#{ENV['cw_ROOT']}/lib/ruby/Gemfile"
  $: << "#{ENV['cw_ROOT']}/lib/ruby/lib"

  require 'rubygems'
  require 'bundler'
  Bundler.setup(:default)
  ####

  t.pattern = "lib/**/tests/test_*.rb"
end

