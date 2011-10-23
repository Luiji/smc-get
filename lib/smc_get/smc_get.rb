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
require "tempfile"
require "digest/sha1"
require "webrick"
begin
  require "psych"
rescue LoadError
end
require "yaml"
require 'uri'
require "open-uri"
require 'net/https'
require "archive/tar/minitar"
require "xz"

require_relative "./errors"
require_relative "./repository"
require_relative "./local_repository"
require_relative "./remote_repository"
require_relative "./package_archive"
require_relative "./package_specification"
require_relative "./package"

#Extend the Hash class with a method to turn all keys into symbols.
class Hash

  #Recursively turns all keys in this hash into symbols. This method
  #is inteded for loading configuration files. Doesn’t modify the receiver.
  def symbolic_keys
    inject({}){|hsh, (k, v)| hsh[k.to_sym] = v.respond_to?(:symbolic_keys) ? v.symbolic_keys : v; hsh}
  end
  
end

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
  Pathname.new(__FILE__).dirname.expand_path.join("..", "..", "VERSION.txt").read.match(/\A(\d+)\.(\d+)\.(\d+)(\-.*?)?\Z/)
  VERSION = {
    :mayor => $1.to_i,
    :minor => $2.to_i,
    :tiny => $3.to_i,
    :dev => $4,
  }
  
  class << self
    
    #The temporary directory used by smc-get.
    attr_reader :temp_dir
    
    #Initializes the library.
    def setup
      @temp_dir = Pathname.new(Dir.mktmpdir("smc-get"))
      at_exit{@temp_dir.rmtree}
      VERSION.freeze #Nobody changes this after initializing anymore!
    end
    
    #Returns smc-get's version by concatenating the VERSION constant's
    #values in a sensible mannor. Return value is a string of form
    #  mayor.minor.tiny[-dev|-rc|-beta1|...] (<date>, commit <commit_num>)
    def version
      str = "#{VERSION[:mayor]}.#{VERSION[:minor]}.#{VERSION[:tiny]}"
      str << VERSION[:dev] if VERSION[:dev]
      str
    end
    
  end
  
end

# vim:set ts=8 sts=2 sw=2 et: #
