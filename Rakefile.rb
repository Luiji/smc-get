#Encoding: UTF-8
################################################################################
# This file is part of smc-get.
# Copyright (C) 2010-2011 Entertaining Software, Inc.
# Copyright (C) 2011 Marvin Gülker
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.
################################################################################

require "rake"
gem "rdoc", ">= 3.4" #Ruby's builtin RDoc is unusable
require "rdoc/task"
require "rake/testtask"
require "rake/gempackagetask"
require_relative "./lib/smc_get"

load "smc-get.gemspec"

#Writes the content of SmcGet::VERSION into the VERSION.txt file.
#The values for :dev, :date and :commit are automatically updated
#by this method.
#
#If you do nothing special, this method will append "-dev" to the
#version. If you want to make a stable version, set ENV["DEV"] to "no".
#If you want another suffix, say "-rc1", set ENV["DEV"] to "rc1".
def update_version
  hsh = SmcGet::VERSION
  
  if ENV["DEV"]
    if ENV["DEV"] =~ /no/i
      hsh[:dev] = false
    else
      hsh[:dev] = "-#{ENV["DEV"]}"
    end
  else
    hsh[:dev] = "-dev"
  end
  hsh[:date] = Time.now.strftime("%d-%m-%Y")
  hsh[:commit] = `git log -n1 --no-color --oneline`.chomp.match(/ /).pre_match
  
  File.open("VERSION.txt", "w") do |f|
    f.write(hsh[:mayor])
    f.write(".")
    f.write(hsh[:minor])
    f.write(".")
    f.write(hsh[:tiny])
    f.write(hsh[:dev]) if hsh[:dev]
    f.puts
    f.puts(hsh[:date])
    f.puts(hsh[:commit])
  end
end

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

Rake::GemPackageTask.new(GEMSPEC).define

namespace :bump do
  
  desc "Shows the current version."
  task :show do
    puts SmcGet.version
  end
  
  desc "Increases the mayor version by 1; pass DEV=no for stable version."
  task :mayor do
    SmcGet::VERSION[:mayor] += 1
    update_version
    puts "Bumped to #{SmcGet.version}."
  end
  
  desc "Increases the minor version by 1; pass DEV=no for stable version."
  task :minor do
    SmcGet::VERSION[:minor] += 1
    update_version
    puts "Bumped to #{SmcGet.version}."
  end
  
  desc "Increases the tiny version by 1; pass DEV=no for stable version."
  task :tiny do
    SmcGet::VERSION[:tiny] += 1
    update_version
    puts "Bumped to #{SmcGet.version}."
  end
  
  desc "Defines the current version as a stable one."
  task :stable do
    ENV["DEV"] = "no"
    update_version
    puts "Made '#{SmcGet.version}' stable."
  end
  
  desc "Defines the current version as an unstable one."
  task :unstable do
    ENV["DEV"] = nil
    update_version
    puts "Made '#{SmcGet.version}' unstable."
  end
  
end

# vim:set ts=8 sts=2 sw=2 et: #