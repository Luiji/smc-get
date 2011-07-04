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

module SmcGet
  
  #This module contains all errors messages that are specific to smc-get.
  module Errors
    
    #Superclass for all errors in this library.
    class SmcGetError < StandardError
    end
    
    #Raises when you did not call SmcGet.setup.
    class LibraryNotInitialized < SmcGetError
      
      #Throws an exception of this class with an appropriate error
      #message if smc-get has not been initialized correctly.
      def self.throw_if_needed!
        if SmcGet.datadir.nil? or SmcGet.repo_url.nil?
          raise(self, "You have to setup smc-get first!")
        end
      end
      
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
      # The type of resource (should be either :music, :graphic, :level or :spec).
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
      
      # Returns true if the resource type is :spec. False otherwise.
      def is_spec?
        @resource_type == :spec
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
    
    #Raised when SmcGet.download timed out.
    class ConnectionTimedOutError < DownloadFailedError
    end
    
    #Raised if a package is damaged or malformed.
    class BrokenPackageError < SmcGetError
    end
    
    #Raised if a package specification file contains rubbish.
    class InvalidSpecification < BrokenPackageError
    end
    
    #Raised when a repository wasn’t found or contains structure errors.
    class InvalidRepository < SmcGetError
      
      #The URI of the repository. For remote repositories the URL, for
      #local repositories the local installation path.
      attr_reader :repository_uri

      #Creates a new instance of this class. Pass in the URL or path to
      #the repository.
      def initialize(repository_uri)
        @repository_uri = repository_uri
      end
      
    end
    
  end
end
# vim:set ts=8 sts=2 sw=2 et: #
