#!/usr/bin/env ruby
#Encoding: UTF-8

module SmcGet
  
  module Errors
    
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
    
  end
end