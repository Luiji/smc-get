#!/usr/bin/env ruby
#Encoding: UTF-8
require "fileutils"
require "test/unit"

if RUBY_VERSION =~ /^1.9/
  require_relative "../lib/smc_get/smc_get"
else #For 1.8 fans
  require File.join(File.expand_path(File.dirname(__FILE__)), "..", "smc_get")
end

class SmcGetCUITest < Test::Unit::TestCase
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
data_directory: #{TEST_DIR}
repo_url: "https://github.com/Luiji/Secret-Maryo-Chronicles-Contributed-Levels/raw/master/"
CONFIG
  
  #List of pacakges to install and inspect wheather they
  #are correctly installed or not.
  TEST_PACKAGES = %w[icy-mountain christmas-2010]
  #To test wheather smc-get does know what to do in case of non-existing packages.
  TEST_INVALID_PACKAGES = %w[sdhrfg jhjjjj]
  #The command to run smc-get
  SMC_GET = File.join(File.expand_path(File.dirname(__FILE__)), "..", "bin", "smc-get")
  
  #Test initialization. Write the config file and ensure the directory we
  #want to download into is available. Run before EACH test.
  def setup
    FileUtils.mkdir_p(TEST_DIR)
    File.open(TEST_CONFIG_FILE, "w"){|f| f.write(TEST_CONFIG)}
  end
  
  #Cleanup afterwards. Delete our testing directory. Run after EACH test.
  def teardown
    FileUtils.rm_rf(TEST_DIR)
  end
  
  #Executes <tt>smc-get str</tt> and returns true on success, false
  #otherwise. Ensures the test configuration file is loaded.
  def smc_get(str)
    system("#{SMC_GET} -c #{TEST_CONFIG_FILE} #{str}")
  end
  
  def test_install
    TEST_PACKAGES.each do |pkg|
      smc_get "install #{pkg}"
      assert(File.file?(File.join(TEST_PACKAGES_DIR, "#{pkg}.yml")), "Package file not found: #{pkg}.yml.")
    end
    TEST_INVALID_PACKAGES.each do |pkg|
      assert(!smc_get("install #{pkg}"), "Command completed on invalid packages without error.")
    end
  end
  
  def test_uninstall
    TEST_PACKAGES.each do |pkg|
      assert(!smc_get("uninstall #{pkg}"), "Uninstalled a noninstalled package successfully.")
      smc_get "install #{pkg}"
      smc_get "uninstall #{pkg}"
      assert(!File.exists?(File.join(TEST_PACKAGES_DIR, "#{pkg}.yml")), "Found after uninstalling: #{pkg}.yml")
    end
    TEST_INVALID_PACKAGES.each do |pkg|
      assert(!smc_get("uninstall #{pkg}"), "Uninstalled an invalid package successfully.")
    end
  end
  
  def test_getinfo
    TEST_PACKAGES.each do |pkg|
      assert(smc_get("getinfo #{pkg}"), "Couldn't retrieve info for #{pkg}.")
    end
    TEST_INVALID_PACKAGES.each do |pkg|
      assert(!smc_get("getinfo #{pkg}"), "Retrieved info for broken package sucessfully.")
    end
  end
  
end
