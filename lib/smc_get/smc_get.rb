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
require_relative "./package"

#This is the main module of smc-get and it's namespace.
module SmcGet
  
  #Root directory of the smc-get program and libraries.
  ROOT_DIR = Pathname.new(__FILE__).dirname.parent.parent
  #Subdirectory for executable files.
  BIN_DIR = ROOT_DIR + "bin"
  #Subdirectory for library files.
  LIB_DIR = ROOT_DIR + "lib"
  #Subdirectory for configuration files.
  CONFIG_DIR = ROOT_DIR + "config"
  
  #Directory where the package specifications are saved to. Relative to the
  #data directory in SmcGet.datadir.
  PACKAGE_SPECS_DIR = "packages".freeze
  #Directory where a package's music files are saved to. Relative to the
  #data directory in SmcGet.datadir.
  PACKAGE_MUSIC_DIR = "music/contrib-music".freeze
  #Directory where a package's graphics files are saved to. Relative to the
  #data directory given in SmcGet.datadir
  PACKAGE_GRAPHICS_DIR = "pixmaps/contrib-graphics".freeze
  #Directory where a package's level files are saved to. Relative to the
  #data directory given in SmcGet.datadir.
  PACKAGE_LEVELS_DIR = "levels".freeze
  
  class << self
    
    #This is the base URL from which packages are downloaded. This
    #should be set to Luiji's level repository.
    attr_accessor :repo_url
    
    #This is the directory in which music, levels, etc. are saved
    #into on the local machine. This should be set to your
    #SMC installation.
    def datadir
      @datadir
    end
    
    #See reader for explanation.
    def datadir=(str)
      @datadir = Pathname.new(str)
    end
    
    @repo_url = nil
    @datadir = nil
    
    # Download the specified raw file from the repository to the specified
    # output file.  URL should be everything in the URL after
    # SmcGet.repo_url.
    # Yields the currently downloaded file and how many percent of that file have
    # already been downloaded if a block is given.
    def download(url, output) # :nodoc:
      Errors::LibraryNotInitialized.throw_if_needed!
      # Make url friendly.
      url = URI::Parser.new.escape(url)
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
