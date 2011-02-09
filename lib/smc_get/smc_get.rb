#!/usr/bin/env ruby
#Encoding: UTF-8

require "pathname"
require 'tempfile'
require "fileutils"
begin
  require "psych"
  YAML = Psych
rescue LoadError
  require 'yaml'
end
require 'uri'
require 'net/https'

require_relative "./errors"

module SmcGet
  
  ROOT_DIR = Pathname.new(__FILE__).dirname.parent.parent
  BIN_DIR = ROOT_DIR + "bin"
  LIB_DIR = ROOT_DIR + "lib"
  CONFIG_DIR = ROOT_DIR + "config"
  
  # The SmcGet class provides a set of functions for managing smc-get packages.
  class SmcGet
        
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
    
    # Initialize an instance of the SmcGet class with the specified
    # configuration file.  The default configuration file is smc-get.yml.
    def initialize(repo_url, datadir)
      @repo_url = repo_url
      @datadir = Pathname.new(datadir)
    end
    
    # Install a package from the repository. Yields the total progress in percent,
    # the name of the file currently being downlaoded and how many percent of that
    # file have already been downloaded.
    def install(package_name) # :yields: percent_total, file, percent_of_file
      percent_total = 0 #For reporting the total progress
      begin
        download(
        "packages/#{package_name}.yml",
        @datadir + PACKAGE_SPECS_DIR + "#{package_name}.yml"
        ) do |file, percent_done|
          yield(percent_total, file, percent_done) if block_given?
        end
      rescue Errors::DownloadFailedError
        raise(Errors::NoSuchPackageError.new(package_name), "ERROR: Package not found in the repository: #{package_name}.")
      end
      
      pkgdata = YAML.load_file(@datadir + PACKAGE_SPECS_DIR + "#{package_name}.yml")
      percent_total = 25 #%
      
      if pkgdata.has_key?('music')
        pkgdata['music'].each do |filename|
          begin
            download(
            "music/#{filename}",
            @datadir + PACKAGE_MUSIC_DIR + filename
            ) do |file, percent_done|
              yield(percent_total, file, percent_done) if block_given?
            end
          rescue Errors::DownloadFailedError => error
            raise(Errors::NoSuchResourceError.new(:music, error.download_url), "ERROR: Music not found in the repository: #{filename}.")
          end
        end
      end
      
      percent_total = 50 #%
      
      if pkgdata.has_key?('graphics')
        pkgdata['graphics'].each do |filename|
          begin
            download(
            "graphics/#{filename}",
            @datadir + PACKAGE_GRAPHICS_DIR + filename
            ) do |file, percent_done|
              yield(percent_total, file, percent_done) if block_given?
            end
          rescue Errors::DownloadFailedError => error
            raise(Errors::NoSuchResourceError.new(:graphic, error.download_url), "ERROR: Graphic not found in the repository: #{filename}.")
          end
        end
      end
      
      percent_total = 75 #%
      
      if pkgdata.has_key?('levels')
        pkgdata['levels'].each_with_index do |filename, index|
          begin
            download(
            "levels/#{filename}",
            @datadir + PACKAGE_LEVELS_DIR + filename
            ) do |file, percent_done|
              #The last value the user shall see are 100%, so in the last
              #iteration we set percent_total to 100.
              percent_total = 100 if index == pkgdata["levels"].count - 1 #Index is 0-based
              yield(percent_total, file, percent_done) if block_given?
            end
          rescue Errors::DownloadFailedError => error
            raise(Errors::NoSuchResourceError.new(:level, error.download_url), "ERROR: Level not found in the repository: #{filename}.")
          end
        end
      end
    end
    
    # Uninstall a package from the local database. If a block is given,
    # it is yielded the total progress in percent, the package part currently being deleted, and
    # how many percent of the files have already been deleted for the current package
    # part.
    def uninstall(package_name) # :yields: percent_total, part, percent_deleted_files
      begin
        pkgdata = YAML.load_file(@datadir + PACKAGE_SPECS_DIR + "#{package_name}.yml")
      rescue Errno::ENOENT
        raise(Errors::NoSuchPackageError.new(package_name), "ERROR: Local package not found: #{package_name}.")
      end
      
      percent_total = 0 #For reporting the total progress
      
      %w[music graphics levels].each_with_index do |part, part_index|
        if pkgdata.has_key? part
          total_files = pkgdata[part].count
          pkgdata[part].each_with_index do |filename, index|
            begin
              File.delete(@datadir + self.class.const_get("PACKAGE_#{part.upcase}_DIR") + filename)
            rescue Errno::ENOENT
            end
            #The last value the user shall see is 100%, so set it in
            #the very last (i.e. last of the outer and inner loop) iteration
            #to 100.
            percent_total = 100 if part_index == 2 and index == total_files - 1
            yield(percent_total, part, ((index + 1) / total_files) * 100) if block_given? #+1, because index is 0-based
          end
        end
        percent_total = ((part_index + 1) / 3.0) * 100 #+1, because index is 0-based (3 is the total number of iterations)
      end
      
      File.delete(@datadir + PACKAGE_SPECS_DIR + "#{package_name}.yml")
    end
    
    # Get package information.  WARNING: This function is not thread-safe.
    def getinfo(package_name, force_remote = false)
      yaml = nil
      if force_remote or !package_installed?(package_name)
        Tempfile.open('pkgdata') do |tmp|
          begin
            download("packages/#{package_name}.yml", tmp.path)
          rescue Errors::DownloadFailedError
            raise(Errors::NoSuchPackageError.new(package_name), "ERROR: Package not found in the repository: #{package_name}")
          end
          yaml = YAML.load_file(tmp.path)
        end
      else
        yaml = YAML.load_file(@datadir + PACKAGE_SPECS_DIR + "#{package_name}.yml")
      end
      return yaml
    end
    
    def package_installed?(package_name)
      @datadir.join(PACKAGE_SPECS_DIR, "#{package_name}.yml").file?
    end
    
    private
    
    # Download the specified raw file from the repository to the specified
    # output file.  URL should be everything in the URL after
    # https://github.com/Luiji/Secret-Maryo-Chronicles-Contributed-Levels/raw/master/.
    # Yields the currently downloaded file and how many percent of that file have
    # already been downloaded if a block is given.
    def download(url, output) # :yields: file, percent_done
      # Make url friendly.
      url = URI.escape(url)
      # Create directories if needed.
      FileUtils.mkdir_p(File.dirname(output))
      # Download file.
      File.open(output, "w") do |outputfile|
        uri = URI.parse(@repo_url + url)
        
        request = Net::HTTP.new(uri.host, uri.port)
        request.use_ssl = true #GitHub uses SSL
        
        request.start do
          #1. Establish connection
          request.request_get(uri.path) do |response|
            raise(Errors::DownloadFailedError.new(url), "Received HTTP error code #{response.code}.") unless response.code == "200"
            #2. Get what size the file is
            final_size = response.content_length
            current_size = 0
            #Ensure the first value the user sees are 0%
            yield(url, 0) if block_given?
            #3. Get the actual file in parts and report percent done.
            response.read_body do |part|
              outputfile.write(part)
              
              current_size += part.size
              percent = (current_size.to_f / final_size.to_f) * 100
              yield(url, percent) if block_given?
            end
          end
          #Ensure the last value the user sees are 100%
          yield(url, 100) if block_given?
        end
      end
    end
    
  end
  
end
