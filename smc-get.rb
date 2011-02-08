#!/usr/bin/env ruby
# smc-get: level repository manager for Secret Maryo Chronicles
# Copyright(C) 2010 Entertaining Software, Inc.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

require 'tempfile'
require "fileutils"
require 'yaml'
require 'uri'
require 'net/https'

# The SmcGet class provides a set of functions for managing smc-get packages.
class SmcGet
  
  #URI where we download everything from. Level names, etc. are
  #appended to it.
  BASE_URI = "https://github.com/Luiji/Secret-Maryo-Chronicles-Contributed-Levels/raw/master/".freeze
  #Directory where the package specifications are saved to. Relative to the
  #data directory given in the configuration file.
  PACKAGE_SPECS_DIR = "packages".freeze
  #Directory where a package's music files are saved to. Relative to the
  #data directory given in the configuration file.
  PACKAGE_MUSIC_DIR = "music/contrib-music".freeze
  #Directory where a package's graphics files are saved to. Relative to the
  #data directory given in the configuration file.
  PACKAGE_GRAPHICS_DIR = "pixmaps/contrib-graphics".freeze
  #Directory where a package's level files are saved to. Relative to the
  #data directory given in the configuration file.
  PACKAGE_LEVELS_DIR = "levels".freeze
  
  #Superclass for all errors in this library.
  class SmcGetError < StandardError
  end
  
  # Raised when the class is initialized with a non-existant settings file.
  class CannotFindSettings < SmcGetError
    # The path to the settings file that was specified.
    attr_reader :settings_path

    # Create a new instance of the exception with the settings path.
    def initialize(settings_path)
      @settings_path = settings_path
    end
  end

  # Raised when a package call is made but the specified package cannot be
  # found.
  class NoSuchPackageError < SmcGetError
    # The name of the package that could not be found.
    attr_reader :package_name

    # Create a new instance of the exception with the specified package name.
    def initialize(name)
      @package_name = name
    end
  end

  # Raised when a package call is made but one of the resources of the
  # specified package is missing.
  class NoSuchResourceError < SmcGetError
    # The type of resource (should be either :music, :graphic, or :level).
    attr_reader :resource_type
    # The name of the resource (i.e. mylevel.lvl or Stuff/Cheeseburger.png).
    attr_reader :resource_name

    # Create a new instance of the exception with the specified resource type
    # and name.  Type should either be :music, :graphic, or :level.
    def initialize(type, name)
      @resource_type = type
      @resource_name = name
    end

    # Returns true if the resource type is :music.  False otherwise.
    def is_music?
      @resource_type == :music
    end

    # Returns true if the resource type is :graphic.  False otherwise.
    def is_graphic?
      @resource_type == :graphic
    end

    # Returns true if the resource type is :level.  False otherwise.
    def is_level?
      @resource_type == :level
    end
  end

  # Raised when a call to download() fails.
  class DownloadFailedError < SmcGetError
    # The URL that failed to download (including everything after /raw/master
    # only).
    attr_reader :download_url

    def initialize(url)
      @download_url = url
    end
  end
  
  # Initialize an instance of the SmcGet class with the specified
  # configuration file.  The default configuration file is smc-get.yml.
  def initialize(config_file = 'smc-get.yml')
    begin
      settings = YAML.load_file(config_file)
    rescue Errno::ENOENT
      raise CannotFindSettings.new(config_file)
    end
    @datadir = settings['data-directory']
  end

  # Install a package from the repository.
  def install(package_name)
    begin
      download(
        "packages/#{package_name}.yml",
        File.join(@datadir, PACKAGE_SPECS_DIR, "#{package_name}.yml")
        )
    rescue DownloadFailedError
      raise NoSuchPackageError.new(package_name)
    end
    
    pkgdata = YAML.load_file(File.join(@datadir, PACKAGE_SPECS_DIR, "#{package_name}.yml"))
    
    if pkgdata.has_key?('music')
      pkgdata['music'].each do |filename|
        begin
          download(
            "music/#{filename}",
            File.join(@datadir, PACKAGE_MUSIC_DIR, filename)
          )
        rescue DownloadFailedError => error
          raise NoSuchResourceError.new(:music, error.download_url)
        end
      end
    end
    
    if pkgdata.has_key?('graphics')
      pkgdata['graphics'].each do |filename|
        begin
          download(
            "graphics/#{filename}",
            File.join(@datadir, PACKAGE_GRAPHICS_DIR, filename)
          )
        rescue DownloadFailedError => error
          raise NoSuchResourceError.new(:graphic, error.download_url)
        end
      end
    end
    
    if pkgdata.has_key?('levels')
      pkgdata['levels'].each do |filename|
        begin
          download(
            "levels/#{filename}",
            File.join(@datadir, PACKAGE_LEVELS_DIR, filename)
          )
        rescue DownloadFailedError => error
          raise NoSuchResourceError.new(:level, error.download_url)
        end
      end
    end
  end

  # Uninstall a package from the local database.
  def uninstall(package_name)
    begin
      pkgdata = YAML.load_file(File.join(@datadir, PACKAGE_SPECS_DIR, "#{package_name}.yml"))
    rescue Errno::ENOENT
      raise NoSuchPackageError.new(package_name)
    end
    
    if pkgdata.has_key?('music')
      pkgdata['music'].each do |filename|
        begin
          File.delete(File.join(@datadir, PACKAGE_MUSIC_DIR, filename))
        rescue Errno::ENOENT
        end
      end
    end
    
    if pkgdata.has_key?('graphics')
      pkgdata['graphics'].each do |filename|
        begin
          File.delete(File.join(@datadir, PACKAGE_GRAPHICS_DIR, filename))
        rescue Errno::ENOENT
        end
      end
    end
    
    if pkgdata.has_key?('levels')
      pkgdata['levels'].each do |filename|
        begin
          File.delete(File.join(@datadir, PACKAGE_LEVELS_DIR, filename))
        rescue Errno::ENOENT
        end
      end
    end

    File.delete("#{@datadir}/packages/#{package_name}.yml")
  end

  # Get package information.  WARNING: This function is not thread-safe.
  def getinfo(package_name)
    yaml = nil
    Tempfile.open('pkgdata') do |tmp|
      begin
        download("packages/#{package_name}.yml", tmp.path)
      rescue DownloadFailedError
        raise NoSuchPackageError.new(package_name)
      end
      yaml = YAML.load_file(tmp.path)
    end
    return yaml
  end

  private

  # Download the specified raw file from the repository to the specified
  # output file.  URL should be everything in the URL after
  # https://github.com/Luiji/Secret-Maryo-Chronicles-Contributed-Levels/raw/master/.
  def download(url, output)
    # Make url friendly.
    url = url.gsub(/ /, '%20')
    # Create directories if needed.
    FileUtils.mkdir_p(File.dirname(output))
    # Download file.
    File.open(output, "w") do |outputfile|
      uri = URI.parse(BASE_URI + url)
      request = Net::HTTP.new(uri.host, uri.port)
      request.use_ssl = true
      request.start do
        request.request_get(uri.path) do |response|
          if response.code != "200" then raise DownloadFailedError.new(url) end
          outputfile.write(response.body)
        end
      end
    end
  end
end

# This code is executed if the script is being executed as a command as supposed
# to being loaded as a library.
if __FILE__ == $0
  if ARGV.length == 0 then ARGV[0] = 'help' end

  begin
    case ARGV[0]
      when 'help'
        puts "Usage: #{$0} COMMAND [PARAMETERS...]"
        puts
        puts 'Install and uninstall levels from the Secret Maryo Chronicles contributed level repository.'
        puts
        puts 'Commands:'
        puts '  install    install a package'
        puts '  uninstall  uninstall a package'
        puts '  getinfo    get information about a package'
        puts '  help       print this help message'
        puts
        puts 'Report bugs to: luiji@users.sourceforge.net'
        puts 'smc-get home page: <http://www.secretmaryo.org/>'

      when 'install'
        smcget = SmcGet.new
        smcget.install(ARGV[1])

      when 'uninstall'
        smcget = SmcGet.new
        smcget.uninstall(ARGV[1])

      when 'getinfo'
        smcget = SmcGet.new
        info = smcget.getinfo(ARGV[1])
        puts "Title: #{info['title']}"
        if info['authors'].count == 1
          puts "Author: #{info['authors'][0]}"
        else
          puts 'Authors:'
          info['authors'].each do |author|
            puts "  - #{author}"
          end
        end
        puts "Difficulty: #{info['difficulty']}"
        puts "Description: #{info['description']}"

      else
        puts "Unrecognized command #{ARGV[0]}."
    end
  rescue SmcGet::CannotFindSettings => error
    puts "Cannot find settings file (\"#{error.settings_path}\")."
  rescue SmcGet::NoSuchPackageError => error
    puts "No such package #{error.package_name}."
  rescue SmcGet::NoSuchResourceError => error
    puts "No such #{error.resource_type} resource #{error.resource_name}."
    puts "Package #{ARGV[1]} has broken dependencies."
    puts "Uninstalling previously installed files for #{ARGV[1]}..."
    smcget.uninstall(ARGV[1])
  end
end
