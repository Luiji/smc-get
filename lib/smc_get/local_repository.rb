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

  #A LocalRepository contains all the packages that are installed locally, i.e.
  #that have been downloaded and added to your local SMC installation.
  #It provides the exact same methods as RemoteRepository, but works completely
  #local and therefore doesn’t need an internet connection as RemoteRepository does.
  #
  #The only notable difference is that instances of this class have some
  #attributes different from those defined for RemoteRepository, but usually
  #you shouldn’t have to worry about that.
  #
  #Concluding, you’ll find the documentation of most of the methods of this class
  #in the documentation of the RemoteRepository class, because duplicating docs
  #doesn’t make much sense.
  class LocalRepository < Repository
    
    #Directory where the package specs are kept.
    SPECS_DIR            = Pathname.new("packages")
    #Directory where downloaded packages are cached.
    CACHE_DIR            = Pathname.new("cache")
    #Directory where the packages’ level files are kept.
    CONTRIB_LEVELS_DIR   = Pathname.new("levels") #Levels in subdirectories are currently not recognized by SMC
    #Directory where the packages’ music files are kept.
    CONTRIB_MUSIC_DIR    = Pathname.new("music") + "contrib-music"
    #Directory where the packages’ graphic files are kept.
    CONTRIB_GRAPHICS_DIR = Pathname.new("pixmaps") + "contrib-graphics"
    #Directory where the packages’ sound files are kept.
    CONTRIB_SOUNDS_DIR   = Pathname.new("sounds") + "contrib-sounds"
    #Directory where the packages’ world files are kept
    CONTRIB_WORLDS_DIR   = Pathname.new("world") #Worlds in subdirectores are currently not recognized by SMC
    
    #Root path of the local repository. Should be the same as your SMC’s
    #installation path.
    attr_reader :path
    #This repository’s specs dir.
    attr_reader :specs_dir
    #This repository’s cache dir.
    attr_reader :cache_dir
    #This repository’s package levels dir.
    attr_reader :contrib_level_dir
    #This repository’s package music dir.
    attr_reader :contrib_music_dir
    #This repository’s package graphics dir.
    attr_reader :contrib_graphics_dir
    #This repository’s package sounds dir.
    attr_reader :contrib_sounds_dir
    #This repository’s package worlds dir.
    attr_reader :contrib_worlds_dir
    #An array of PackageSpecification objects containing the specs of
    #all packages installed in this repository.
    attr_reader :package_specs

    #"Creates" a new local repository whose root is located at the given +path+.
    #When instanciating this class, you should point it to the root of your
    #SMC installation’s *share* directory, e.g. <b>/usr/share/smc</b>.
    #==Parameter
    #[path] The path to your SMC installation.
    #==Return value
    #The newly created LocalRepository.
    #==Example
    #  lr = SmcGet::LocalRepository.new("/usr/share/smc")
    #==Remarks
    #smc-get requires some additional directories in your SMC installation,
    #namely (where +smc+ is your SMC’s *share* directory):
    #  * smc/packages
    #  * smc/music/contrib-music
    #  * smc/sounds/contrib-sounds
    #  * smc/pixmaps/contrib-graphics
    #These will be created when you call this method, so make sure
    #you have the appropriate permissions for these directories or
    #you’ll get an Errno::EACCES exception when calling ::new.
    def initialize(path)
      @path         = Pathname.new(path)
      @specs_dir    = @path + SPECS_DIR
      @cache_dir    = @path + CACHE_DIR
      @levels_dir   = @path + CONTRIB_LEVELS_DIR
      @music_dir    = @path + CONTRIB_MUSIC_DIR
      @graphics_dir = @path + CONTRIB_GRAPHICS_DIR
      @sounds_dir   = @path + CONTRIB_SOUNDS_DIR
      @worlds_dir   = @path + CONTRIB_WORLDS_DIR
      
      #Create the directories if they’re not there yet
      [@specs_dir, @cache_dir, @levels_dir, @music_dir, @graphics_dir, @sounds_dir, @worlds_dir].each do |dir|
        dir.mkpath unless dir.directory?
      end
      
      @package_specs = []
      @specs_dir.children.each do |spec_path|
        next unless spec_path.to_s.end_with?(".yml")
        @package_specs << PackageSpecification.from_file(spec_path)
      end
    end
    
    def fetch_spec(spec_file, directory = ".")
      directory = Pathname.new(directory)
      
      spec_file_path = @specs_dir + spec_file
      raise(Errors::NoSuchResourceError.new(:spec, spec_file), "Package specification '#{spec_file}' not found in the local repository '#{to_s}'!") unless spec_file_path.file?
      
      directory.mktree unless directory.directory?
      
      #No need to really "fetch" the spec--this is a *local* repository.
      FileUtils.cp(spec_file_path, directory)
      directory + spec_file
    end
    
    def fetch_package(pkg_file, directory = ".")
      directory = Pathname.new(directory)
      
      pkg_file_path = @cache_dir + pkg_file
      raise(Errors::NoSuchPackageError.new(pkg_file.sub(/\.smcpak/, "")), "Package file '#{pkg_file}' not found in this repository's cache!") unless pkg_file_path.file?
      
      directory.mktree unless directory.directory?
      
      #No need to really "fetch" the package--this is a *local* repository
      FileUtils.cp(pkg_file_path, directory)
      directory + pkg_file
    end
    
    def install(package, &block)
      path = package.decompress(SmcGet.temp_dir) + package.spec.name
      
      package.spec.save(@specs_dir)
      
      FileUtils.cp_r(path.join(Package::LEVELS_DIR).children, @levels_dir)
      FileUtils.cp_r(path.join(Package::MUSIC_DIR).children, @music_dir)
      FileUtils.cp_r(path.join(Package::GRAPHICS_DIR).children, @graphics_dir)
      FileUtils.cp_r(path.join(Package::SOUNDS_DIR).children, @sounds_dir)
      FileUtils.cp_r(path.join(Package::WORLDS_DIR).children, @worlds_dir)
      
      FileUtils.cp(package.path, @cache_dir)
      
      @package_specs << package.spec #This package is now installed and therefore the spec must be in that array
    end
    
    def uninstall(pkg_name)
      spec = @package_specs.find{|spec| spec.name == pkg_name}
      
      [:levels, :music, :sounds, :graphics, :worlds].each do |sym|
        contrib_dir = @path + self.class.const_get(:"CONTRIB_#{sym.upcase}_DIR")
        
        #Delete all the files
        files = spec[sym]
        files.each do |filename|
          File.delete(contrib_dir + filename)
        end
        
        #Delete now empty directories
        loop do
          empty_dirs = []
          contrib_dir.find do |path|
            next if path == contrib_dir #We surely don’t want to delete the toplevel dir.
            empty_dirs << path if path.directory? and path.children.empty?
          end
          #If no empty directories are present anymore, break out of the loop.
          break if empty_dirs.empty?
          #Otherwise delete the empty directories and redo the process, because
          #the parent directories could be empty now.
          empty_dirs.each{|path| File.delete(path)}
        end
      end

      File.delete(@specs_dir + spec.spec_file_name) #Remove the spec itself
      @package_specs.delete(spec) #Otherwise we have a stale package in the array
    end

    #Returns the path this repository refers to.
    def to_s
      @path.to_s
    end
    
    def contain?(pkg)
      if pkg.kind_of? Package
        @package_specs.include?(pkg.spec)
      else
        @package_specs.any?{|spec| spec.name == pkg}
      end
    end
    alias contains? contain?

    def search(regexp, *attributes)
      attributes << :name if attributes.empty? #Default value
      
      @package_specs.each do |spec|
        attributes.each do |att|
          case att
          when :name        then yield(spec.name) if spec.name =~ regexp
          when :title       then yield(spec.name) if spec.title =~ regexp
          when :authors     then yield(spec.name) if spec.authors.any?{|a| a =~ regexp}
          when :difficulty  then yield(spec.name) if spec.difficulty =~ regexp
          when :description then yield(spec.name) if spec.description =~ regexp
          when :levels      then yield(spec.name) if spec.levels.any?{|l| l =~ regexp}
          when :music       then yield(spec.name) if spec.music.any?{|m| m =~ regexp}
          when :sounds      then yield(spec.name) if spec.sound.any?{|s| s =~ regexp}
          when :graphics    then yield(spec.name) if spec.graphics.any?{|g| g =~ regexp}
          when :worlds      then yield(spec.name) if spec.worlds.any?{|w| w =~ regexp}
          else
            $stderr.puts("Warning: Unknown attribute #{att}, ignoring it.")
          end #case
        end #attributes.each
      end # @package_specs.each
    end #search
    
  end #LocalRepository
  
end
