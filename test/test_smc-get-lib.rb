#!/usr/bin/env ruby
#Encoding: UTF-8
require "fileutils"
require "test/unit"

if RUBY_VERSION =~ /^1.9/
  require_relative "../smc-get"
else #For 1.8 fans
  require File.join(File.expand_path(File.dirname(__FILE__)), "..", "smc_get")
end

#Test case for SmcGet. If the tests defined here don't fail, everything
#works well.
class SmcGetLibraryTest < Test::Unit::TestCase
  
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
  
  #Test initialization. Write the config file and ensure the directory we
  #want to download into is available. Run before EACH test.
  def setup
    #For getting everything right as it is outputted
    $stdout.sync = $stderr.sync = true
    SmcGet.output_info = true
    
    FileUtils.mkdir_p(TEST_DIR)
    File.open(TEST_CONFIG_FILE, "w"){|f| f.write(TEST_CONFIG)}
    @smc_get = SmcGet.new(TEST_CONFIG_FILE)
  end
  
  #Cleanup afterwards. Delete our testing directory. Run after EACH test.
  def teardown
    FileUtils.rm_rf(TEST_DIR)
  end
  
  #Tests the library's install routine.
  def test_install
    TEST_PACKAGES.each do |pkg|
      puts "Test installing #{pkg}"
      @smc_get.install(pkg)
    
      pkg_config_file = File.join(TEST_PACKAGES_DIR, pkg + ".yml")
      assert(File.file?(pkg_config_file), "Package config file for #{pkg} not found.")
      
      pkg_config = YAML.load_file(pkg_config_file)
      
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
      assert_raises(SmcGet::NoSuchPackageError){@smc_get.install(pkg)}
    end
  end
  
  #def test_incorrect_install
  # #Maybe installed twice?
  #end
  
  def test_uninstall
    TEST_PACKAGES.each do |pkg|
      puts "Test uninstalling #{pkg}"
      @smc_get.install(pkg) #We can't uninstall a package that is not installed
  
      pkg_config_file = File.join(TEST_PACKAGES_DIR, pkg + ".yml")
      pkg_config = YAML.load_file(pkg_config_file)
  
      @smc_get.uninstall(pkg)
      assert(!File.exists?(pkg_config_file), "File found after uninstalling: #{pkg_config_file}.")
  
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
      assert_raises(SmcGet::NoSuchPackageError){@smc_get.uninstall(pkg)}
    end
  end
  
  def test_getinfo
    TEST_PACKAGES.each do |pkg|
      puts "Test getting info about #{pkg}"
      @smc_get.install(pkg) #We can't check specs from packages not installed
  
      pkg_config_file = File.join(TEST_PACKAGES_DIR, pkg + ".yml")
      pkg_config = YAML.load_file(pkg_config_file)
  
      assert_equal(pkg_config, @smc_get.getinfo(pkg))
    end
  
    TEST_INVALID_PACKAGES.each do |pkg|
      assert_raises(SmcGet::NoSuchPackageError){@smc_get.getinfo(pkg)}
    end
  end
  
end