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

  #A PackageSpecification object is a mostly informational object
  #directly related to Package objects. That is, each and every
  #Package instance has a Package#spec method that will retrieve
  #the PackageSpecification, an instance of this class, for you:
  #
  #  puts pkg.spec.title #=> Cool package
  #
  #Instances of this class can be understood as the parsed content of
  #a package’s specification file. It has getter and setter methods
  #reflecting the keys that are allowed in the specification (see
  #the smcpak.rdoc file), but unless you want to build smc packages,
  #there’s no need for you to use the setter methods.
  class PackageSpecification
    
    #The keys listed here must be mentioned inside a package spec,
    #otherwise the package is considered broken.
    SPEC_MANDATORY_KEYS = [:title, :last_update, :authors, :difficulty, :description, :checksums].freeze
    
    ##
    # :attr_accessor: title
    #The package’s title.

    ##
    # :attr_accessor: last_update
    #The time (an instance of class Time) indicating when the package
    #was last updated.
    
    ##
    # :attr_accessor: authors
    #The authors of this package. An array.
    
    ##
    # :attr_accessor: difficulty
    #The difficulty of this package as a string.
    
    ##
    # :attr_accessor: description
    #The description of this package.
    
    ##
    # :attr_accessor: install_message
    #A message to display during installation of this package or nil if
    #no message shall be displayed.
    
    ##
    # :attr_accessor: remove_message
    #A message to display during removing of this package or nil if no
    #message shall be displayed.
    
    ##
    # :attr_accessor: dependecies
    #An array of package names this package depends on, i.e. packages that
    #need to be installed before this one can be installed. The array is
    #empty if no dependecies exist.
    
    ##
    # :attr_accessor: levels
    #An array of level file names (strings).
    
    ##
    # :attr_accessor: music
    #An array of music file names (strings).
    
    ##
    # :attr_accessor: sounds
    #An array of sound file names (strings).
    
    ##
    # :attr_accessor: graphics
    #An array of graphic file names (strings).
    
    ##
    # :attr_accessor: worlds
    #An array of graphic file names (strings).

    ##
    # :attr_accessor: checksums
    #A hash that maps each filename in this package to it’s SHA1 checksum.
    
    #The name of the package this specification is used in, without any
    #file extension.
    attr_reader :name
    
    ##
    # :attr_reader: compressed_file_name
    #The name of the compressed file this specification should belong to.
    #The same as name, but the extension .smcpak was appended.
    
    ##
    # :attr_reader: spec_file_name
    #The name of the specification file. The same as name, but
    #the extension .yml was appended.

    #Creates a PackageSpecification by directly reading a complete
    #spec from a YAML file.
    #==Parameter
    #[path] The path to the file to read.
    #==Return value
    #An instance of this class.
    #==Raises
    #[InvalidSpecification] +path+ was not found or was malformatted.
    #==Example
    #  path = remote_repo.fetch_spec("cool_pkg.yml")
    #  spec = SmcGet::PackageSpecification.from_file(path)
    #  puts spec.title #=> "Cool package"
    #==Remarks
    #This method may be useful if you don’t need a full-blown
    #Package object and just want to deal with it’s most important
    #attributes.
    def self.from_file(path)
      info = nil
      begin
        info = YAML.load_file(path.to_s)
      rescue Errno::ENOENT => e
        raise(Errors::InvalidSpecification, "File '#{path}' doesn't exist!")
      rescue => e
        raise(Errors::InvalidSpecification, "Invalid YAML: #{e.message}")
      end
      
      spec = new(File.basename(path).sub(/\.yml$/, ""))
      info.each_pair do |key, value|
        spec.send(:"#{key}=", value)
      end
      #TODO: Convert the strings in :checksums to strings, except the
      #filenames, those should be strings. Anyone???
      
      raise(Errors::InvalidSpecification, spec.validate.first) unless spec.valid?
      
      spec
    end
    
    #Returns the matching package name from the package specification’s name
    #by replacing the .yml extension with .smcpak.
    #==Return value
    #A string ending in ".smcpak".
    #==Example
    #  p SmcGet::PackageSpecification.spec2pkg("cool_pkg.yml") #=> "cool_pkg.smcpak")
    def self.spec2pkg(spec_file_name) # :nodoc:
      spec_file_name.to_s.sub(/\.yml$/, ".smcpak")
    end
    
    #Returns the matching specification file name from the package’s name
    #by replacing the .smcpak extension with .yml.
    #==Return value
    #A string ending in ".yml"
    #==Example
    #  p SmcGet::PackageSpecification.pkg2spec("cool_pkg.smcpak") #=> "cool_pkg.yml"
    def self.pkg2spec(package_file_name) # :nodoc:
      package_file_name.to_s.sub(/\.smcpak$/, ".yml")
    end
    
    def initialize(pkg_name)
      @info = {:dependencies => [], :levels => [], :music => [], :sounds => [], :graphics => [], :worlds => []}
      @name = pkg_name
    end
    
    #See attribute.
    def compressed_file_name # :nodoc:
      "#@name.smcpak"
    end
    
    #See attribute.
    def spec_file_name # :nodoc:
      "#@name.yml"
    end
    
    [:title, :last_update, :authors, :difficulty, :description, :install_message, :remove_message, :dependencies, :levels, :music, :sounds, :graphics, :worlds, :checksums].each do |sym|
      define_method(sym){@info[sym]}
      define_method(:"#{sym}="){|val| @info[sym] = val}
    end
    
    def [](sym)
      if respond_to?(sym)
        send(sym)
      else
        raise(IndexError, "No such specification key: #{sym}!")
      end
    end
    
    def valid?
      validate.empty?
    end
    
    def validate
      errors = []
      
      SPEC_MANDATORY_KEYS.each do |sym|
        errors << "Mandatory key #{sym} is missing!" unless @info.has_key?(sym)
      end
      
      errors
    end
    
    #Compares two specifications. They are considered equal if all their
    #attributes (levels, difficulty, etc.) are equal.
    def ==(other)
      return false unless other.respond_to? :info
      @info == other.info
    end

    #Saves the package specification in YAML format into a file.
    #==Parameter
    #[directory] The directory where to save the file to. The filename is automatically
    #            detected from the attributes set for the specification.
    #==Raises
    #[InvalidSpecification] The specification was not valid, i.e. contained incorrect
    #                       or missing values.
    #==Example
    #  p spec.name                  #=> "cool_pkg"
    #  spec.save(".")
    #  p File.file?("cool_pkg.yml") #=> true
    def save(directory)
      raise(Errors::InvalidSpecification, validate.first) unless valid?
      
      path = Pathname.new(directory) + "#{@name}.yml"
      #Turn the spec keys for serialization into strings
      hsh = {}
      @info.each_pair{|k, v| hsh[k.to_s] = v}
      path.open("w"){|f| YAML.dump(hsh, f)}
    end
    
    protected

    #Returns the complete internal information hash.
    def info
      @info
    end
    
  end
  
end
