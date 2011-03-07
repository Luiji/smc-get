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

require "pathname"
require 'tempfile'
require "fileutils"
begin
  require "psych"
  YAML = Psych unless defined?(YAML)
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
  #The name of the file containing the list of all levels in the
  #repository.
  PACKAGE_LIST_FILE = "#{PACKAGE_SPECS_DIR}/packages.lst".freeze
  #The version of smc-get.
  Pathname.new(__FILE__).dirname.expand_path.join("..", "..", "VERSION.txt").read.match(/\A(\d+)\.(\d+)\.(\d+)(\-.*?)?\n(.*?)\n(.*?)\Z/)
  VERSION = {
    :mayor => $1.to_i,
    :minor => $2.to_i,
    :tiny => $3.to_i,
    :dev => $4,
    :date => $5,
    :commit => $6
  }
  
  class << self
    
    #The URL of the repository.
    attr_reader :repo_url
    #The directory where SMC is installed.
    attr_reader :datadir
    
    @repo_url = nil
    @datadir = nil
    
    #Initializes the library. Pass in the URL from which you want
    #to downloaded packages (most likely Luiji's contributed level
    #repository at <tt>https://github.com/Luiji/Secret-Maryo-Chronicles-Contributed-Levels/raw/master/</tt>)
    #and the directory where SMC is installed (something along the lines of
    #<b>/usr/share/smc</b>). Note you *have* to call this method before
    #you can make use of the smc-get library; otherwise you'll get bombed
    #by SmcGet::Errors::LibraryNotInitialized exceptions.
    #
    #You may call this method more than once if you want to reinitialize
    #the library to use other resources.
    def setup(repo_url, datadir)
      @repo_url = repo_url
      @datadir = Pathname.new(datadir)
      VERSION.freeze #Nobody changes this after initializing anymore!
    end
    
    #Returns smc-get's version by concatenating the VERSION constant's
    #values in a sensible mannor. Return value is a string of form
    #  mayor.minor.tiny[-dev|-rc|-beta1|...] (<date>, commit <commit_num>)
    def version
      str = "#{VERSION[:mayor]}.#{VERSION[:minor]}.#{VERSION[:tiny]}"
      str << VERSION[:dev] if VERSION[:dev]
      str << " (#{VERSION[:date]}, commit #{VERSION[:commit]})"
      str
    end
    
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
        
        begin
          request.start do
            #1. Establish connection
            request.request_get(uri.path) do |response|
              raise(Errors::DownloadFailedError.new(url), "ERROR: Received HTTP error code #{response.code}.") unless response.code == "200"
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
        rescue Timeout::Error
          raise(Errors::ConnectionTimedOutError.new(url), "ERROR: Connection timed out.")
        end
      end
    end
    
  end
  
end
