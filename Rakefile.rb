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

# vim:set ts=8 sts=2 sw=2 et: #
