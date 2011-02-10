#!/usr/bin/env ruby
#Encoding: UTF-8

require "rake"
gem "rdoc", ">= 3.4" #Ruby's builtin RDoc is unusable
require "rdoc/task"
require "rake/testtask"

Rake::RDocTask.new do |rd|
  rd.rdoc_files.include("lib/**/*.rb", "**/*.rdoc")
  rd.title = "smc-get RDocs"
  rd.main = "README.rdoc"
  rd.generator = "hanna" #Does nothing if hanna-nouveau is not installed
  rd.rdoc_dir = "doc"
end

Rake::TestTask.new do |t|
  t.pattern = "test/test_*.rb"
  t.warning = true
end
