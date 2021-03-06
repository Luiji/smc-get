#!/usr/bin/env ruby
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

require "fileutils"
require "test/unit"

if RUBY_VERSION =~ /^1.9/
  require_relative "../lib/smc_get/smc_get"
else #For 1.8 fans
  require File.join(File.expand_path(File.dirname(__FILE__)), "..", "smc_get")
end

#Test case for SmcGet. If the tests defined here don't fail, everything
#works well.
class SmcGetLibraryTest < Test::Unit::TestCase
  
  #Directory from which packages are downloaded for the test.
  TEST_REPO = "https://github.com/Luiji/Secret-Maryo-Chronicles-Contributed-Levels/raw/master/"
  #Directory where we will download everything into. It's "testdir" right in this directory.
  TEST_DIR = File.join(File.expand_path(File.dirname(__FILE__)), "testdir")
  TEST_PACKAGES_DIR = File.join(TEST_DIR, "packages")
  TEST_PACKAGES_MUSIC_DIR = File.join(TEST_PACKAGES_DIR, "contrib-music")
  TEST_PACKAGES_GRAPHICS_DIR = File.join(TEST_PACKAGES_DIR, "contrib-graphics")
  TEST_PACKAGES_LEVELS_DIR = File.join(TEST_PACKAGES_DIR, "levels")
  #Test configuration file's location. Inside the test dir, so we're able to
  #delete it together with everything else.
  TEST_CONFIG_FILE = File.join(TEST_DIR, "testconf.yml")
  
  #The configuration file we use for this tests.
  TEST_CONFIG =<<CONFIG
---
data-directory: #{TEST_DIR}
CONFIG
  
  #List of pacakges to install and inspect wheather they
  #are correctly installed or not.
  TEST_PACKAGES = %w[icy-mountain christmas-2010]
  #To test wheather smc-get does know what to do in case of non-existing packages.
  TEST_INVALID_PACKAGES = %w[sdhrfg jhjjjj]
  
  TEST_SEARCH_TERMS = ["icy", /icy/]
  TEST_SEARCH_TERMS_NOT_FOUND = ["dfgd", /^nonexistant$/]
  
  #Test initialization. Write the config file and ensure the directory we
  #want to download into is available. Run before EACH test.
  def setup
    FileUtils.mkdir_p(TEST_DIR)
    File.open(TEST_CONFIG_FILE, "w"){|f| f.write(TEST_CONFIG)}
    SmcGet.setup(TEST_REPO, TEST_DIR)
  end
  
  #Cleanup afterwards. Delete our testing directory. Run after EACH test.
  def teardown
    FileUtils.rm_rf(TEST_DIR)
  end
  
  #Tests the library's install routine.
  def test_install
    TEST_PACKAGES.each do |pkg|
      puts "Test installing #{pkg}"
      package = SmcGet::Package.new(pkg)
      package.install
          
      assert(package.spec_file.file?, "Package config file for #{pkg} not found.")
      
      pkg_config = YAML.load_file(package.spec_file.to_s)
      
      Dir.chdir(TEST_DIR) do
        [%w[levels levels], %w[music music/contrib-music], %w[graphics pixmaps/contrib-graphics]].each do |part, dir|
          next unless pkg_config.has_key?(part)
          pkg_config[part].each do |file|
            assert(File.file?(File.join(dir, file)), "File not found after installing: #{file}.")
          end
        end
      end
    end
    
    TEST_INVALID_PACKAGES.each do |pkg|
      assert_raises(SmcGet::Errors::NoSuchPackageError){SmcGet::Package.new(pkg).install}
    end
    assert_equal(TEST_PACKAGES.count, SmcGet::Package.installed_packages.count)
  end
  
  #def test_incorrect_install
  # #Maybe installed twice?
  #end
  
  def test_uninstall
    TEST_PACKAGES.each do |pkg|
      puts "Test uninstalling #{pkg}"
      package = SmcGet::Package.new(pkg)
      package.install #We can't uninstall a package that is not installed
            
      pkg_config = YAML.load_file(package.spec_file)
  
      package.uninstall
      assert(!package.spec_file.exist?, "File found after uninstalling: #{package.spec_file}.")
      
      Dir.chdir(TEST_DIR) do
        [%w[levels levels], %w[music music/contrib-music], %w[graphics pixmaps/contrib-graphics]].each do |part, dir|
          next unless pkg_config.has_key?(part)
          pkg_config[part].each do |file|
            assert(!File.exists?(File.join(dir, file)), "File found after uninstalling: #{file}.")
          end
        end
      end
    end
  
    TEST_INVALID_PACKAGES.each do |pkg|
      assert_raises(SmcGet::Errors::NoSuchPackageError){SmcGet::Package.new(pkg).uninstall}
    end
    assert_equal(0, SmcGet::Package.installed_packages.count)
  end
  
  def test_getinfo
    TEST_PACKAGES.each do |pkg|
      puts "Test getting info about #{pkg}"
      package = SmcGet::Package.new(pkg)
      package.install #We can't check specs from packages not installed
        
      pkg_config = YAML.load_file(package.spec_file)
  
      assert_equal(pkg_config, package.getinfo)
    end
  
    TEST_INVALID_PACKAGES.each do |pkg|
      assert_raises(SmcGet::Errors::NoSuchPackageError){SmcGet::Package.new(pkg).getinfo}
    end
  end
  
  def test_search
    TEST_SEARCH_TERMS.each do |query|
      ary = SmcGet::Package.search(query)
      pkg = ary[0]
      assert_not_equal(0, ary.size)
      
      pkg.install
      
      ary = SmcGet::Package.search(query, [:pkgname], true)
      assert_not_equal(0, ary.size)
      
      pkg.uninstall
      
      ary = SmcGet::Package.search(query, [:pkgname], true)
      assert_equal(0, ary.size)
    end
    TEST_SEARCH_TERMS_NOT_FOUND.each do |query|
      assert_equal(0, SmcGet::Package.search(query).size)
    end
  end
  
end
