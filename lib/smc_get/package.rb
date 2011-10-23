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
  
  #Packages are the main objects you will have to deal with. An instance of
  #class Package encapsulates all known information from a smc package file
  #(these files are described in the smcpak.rdoc file), and the most important
  #attribute of this class is +spec+, which is your direct interface to the
  #package’s specification by providing you with a fitting instance of class
  #PackageSpecification.
  #
  #Apart from inspecting existing packages, you can also use the Package class
  #to create new pacakges by calling the ::create method (inspecting a given
  #package file is possible with ::from_file). ::create expects a path to
  #the directoy which you want to compress into a new SMC package, validates
  #it against the packaging guidelines and will then either fail or do
  #the actual compression, outputting an instance of class Package that
  #(you guessed it) describes the newly created SMC package.
  #
  #==Example of building a SMC package
  #The following is an example that shows you how to build a basic
  #SMC package by use of the ::create method.
  #
  #First you have to decide how you want to name your package. If you
  #have decided (remember: This is a decision for life!), create a
  #directory named after the package, note that it isn’t allowed to
  #contain whitespace.
  #
  #Inside the directory, say you named it +cool+, create the following
  #structure:
  #
  #  cool/
  #    - cool.yml
  #    - README.txt
  #    levels/
  #    music/
  #    pixmaps/
  #    sounds/
  #    worlds/
  #
  #If your package doesn’t contain a specific component, e.g. sounds, you
  #may ommit the corresponding directory.
  #
  #Then add all the levels you want to include in the package to the +levels+
  #subdirectory, e.g. if you have a level named "awesome_1" and one named
  #"awesome_2", copy them from your personal SMC directory (usually
  #<b>~/.smc/levels</b>) so that your structure looks like this:
  #
  #  cool/
  #    - cool.yml
  #    - README.txt
  #    levels/
  #      - awesome_1.smclvl
  #      - awesome_2.smclvl
  #    music/
  #    pixmaps/
  #    sounds/
  #    worlds/
  #
  #Now the most important step. Open up *cool.yml* in your favourite text
  #editor and write the package specification. You can read about the exact
  #format with all available options in the smcpak.rdoc file,but for now
  #just write the following:
  #
  #  ---
  #  title: Cool levels
  #  last_update: 01-01-2011 04:07:00Z
  #  levels:
  #    - awesome_1.smclvl
  #    - awesome_2.smclvl
  #  authors:
  #    - Your Name Here
  #  difficulty: medium
  #  description: |
  #    Here goes your description
  #    which may span multiple lines.
  #
  #Of course put something appropriate into the +last_update+ field
  #(the format is DD-MM-YYYY hh:mm:ssZ, time zone is UTC).
  #
  #After you wrote something into your README.txt (whatever it is),
  #you *could* build the package the easy way with
  #  $ cd /path/to/dir/above/cool
  #  $ smc-get build cool
  #on the commandline. But I promised you to show the use of
  #Package.create, so instead do:
  #  $ cd /path/to/dir/above/cool
  #  $ ruby -Ipath/to/smcget/lib -rsmc_get -e 'SmcGet::Package.create("cool")'
  #Either way, you should now end up with a file called *cool.smcpak* in the
  #parent directory of <b>cool/</b>.
  class Package
    
    #A package name is considered valid if it matches this Regular
    #expression.
    VALID_PKG_NAME = /^[a-zA-Z_\-0-9]+$/
    #Name of the directory the levels reside in the package.
    LEVELS_DIR   = "levels"
    #Name of the directory the music resides in the package.
    MUSIC_DIR    = "music"
    #Name of the directory the sounds reside in the package.
    SOUNDS_DIR   = "sounds"
    #Name of the dierctory the graphics reside in the pacakge.
    GRAPHICS_DIR = "pixmaps"
    #Name of the directory the worlds reside in the package.
    WORLDS_DIR   = "worlds"
    
    #The PackageSpecification of this package.
    attr_reader :spec
    #The Pathname of the .smcpak file.
    attr_reader :path
    
    class << self
      
      #Creates a new Package from a local .smcpak file.
      #==Parameter
      #[file] The path to the SMC package.
      #==Return value
      #An instance of class Package.
      #==Example
      #  pkg = SmcGet::Package.from_file("/home/freak/mycoolpackage.smcpak")
      #==Remarks
      #As this needs to decompress the package temporarily, this method
      #may take some time to complete.
      def from_file(file)
        pkg_name = File.basename(file).sub(/\.smcpak$/, "")
        #No spec file is provided, we therefore need to extract it from
        #the archive.
        path = PackageArchive.new(file).decompress(SmcGet.temp_dir) + pkg_name + "#{pkg_name}.yml"
        new(path, file)
      end

      #Validates +directory+ against the packaging guidelines and compresses it
      #into a .smcpak file.
      #==Parameter
      #[directory] The path to the directory you want to compress.
      #==Return value
      #An instance of this class describing the newly created package.
      #==Example
      #  pkg = SmcGet::Package.create("/home/freak/mycoollevels")
      #==Remarks
      #The .smcpak file is placed in the parent
      #directory of +directory+, you should therefore ensure you have write
      #permissions for it.
      def create(directory)
        #0. Determine the names of the important files
        directory = Pathname.new(directory)
        pkg_name = directory.basename.to_s
        spec_file = directory + "#{pkg_name}.yml"
        readme = directory + "README.txt"
        smcpak_file = directory.parent + "#{pkg_name}.smcpak"
        
        #1. Validate the package name
        raise(Errors::BrokenPackageError, "Invalid package name!") unless pkg_name =~ VALID_PKG_NAME
        
        #2. Validate the package spec
        spec = PackageSpecification.from_file(spec_file) #Raises if necessary
        
        #3. Validate the rest of the structure
        %w[levels pixmaps music sounds worlds].each do |str|
          dir = directory + str
          raise(Errors::BrokenPackageError, "Directory #{str} missing!") unless dir.directory?
        end

        #Warnings
        $stderr.puts("Warning: No README.txt found.") unless readme.file?
        $stderr.puts("Warning: No levels found.") if spec.levels.empty?
        
        #4. Compress the whole thing
        path = PackageArchive.compress(directory, smcpak_file).path
        from_file(path)
      end
      
    end

    #Creates a new Package from the given specification file. You shouldn’t
    #use this method directly, because you would duplicate the
    #work the ::from_file method already does for you.
    #==Parameters
    #[spec_file]    The path to the YAML specification file.
    #[pkg_location] The path to the SMC package.
    #==Return value
    #The newly created Package instance.
    #==Example
    #  pkg = SmcGet::Package.new("/home/freak/cool.yml", "/home/freak/cool.smcpak")
    def initialize(spec_file, pkg_location)
      @spec = PackageSpecification.from_file(spec_file)
      @path = pkg_location
    end
    
    #Decompresses this package.
    #==Parameter
    #[directory] Where to extract the SMC package to. A subdirectory named after
    #            the package is automatically created in this directory.
    #==Return value
    #The Pathname to the created subdirectory.
    #==Example
    #  pkg.decompress(".") #=> /home/freak/cool
    def decompress(directory)
      PackageArchive.new(@path).decompress(directory)
    end
    
    #Compares two packages. They’re considered equal if their package
    #specifications are equal. See PackageSpecification#==.
    def ==(other)
      return false unless other.respond_to? :spec
      @spec == other.spec
    end

    #Shorthand for:
    #  pkg.spec.name
    def to_s
      @spec.name
    end
    
    #Human-readabe description of form
    #  #<SmcGet::Package <package name>>
    def inspect
      "#<#{self.class} #{@spec.name}>"
    end
    
  end
  
end
