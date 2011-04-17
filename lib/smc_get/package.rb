#Encoding: UTF-8

module SmcGet
  
  #An object of this class represents a local or remote package that is
  #compressed in the .smcpak format (described in the smcpak.rdoc file). A
  #package is considered to be a local one if it isn’t associated with any
  #repository, i.e. it’s +package_location+ attribute is no instance of one
  #of the Repository classes (note here: Local repositories are repositories
  #too, and this means a package installed in a local repository will be
  #considered remote). When you create a Package via the
  #from_repository class method, the specification file you passed to
  #the method will be downloaded if the repository is of class RemoteRepository.
  #Local repositories of course don’t cause any network traffic.
  class Package
    
    #A package name is considered valid if it matches this Regular
    #expression.
    VALID_PKG_NAME = /^[a-zA-Z_0-9]+$/
    
    LEVELS_DIR   = "levels"
    MUSIC_DIR    = "music"
    SOUNDS_DIR   = "sounds"
    GRAPHICS_DIR = "pixmaps"
    WORLDS_DIR   = "worlds"
    
    #The PackageSpecification of this package.
    attr_reader :spec
    #Either the Repository in which the package is contained, or the
    #Pathname of a bare .smcpak file.
    attr_reader :location
    
    class << self
      
      #Creates a new Package from the name of a package
      #specification file and the repository in which it resides.
      #The specification file will be downloaded into a temporary directory, but
      #not the whole package of course.
      def from_repository(repository, spec_file)
        path = repository.kind_of?(LocalRepository) ? spec_file : repository.fetch_spec(spec_file, SmcGet.temp_dir)
        new(path, repository)
      end
      
      #Creates a new Package from a local .smcpak file.
      def from_file(file)
        pkg_name = File.basename(file).sub(/\.smcpak$/, "")
        path = PackageArchive.new(file).decompress(SmcGet.temp_dir) + pkg_name + "#{pkg_name}.yml"
        new(path, file)
      end
      
      #Validates +directory+ against the packaging guidelines, compresses it
      #into a .smcpak file and finally returns a (local) Package
      #object wrapping the file. The .smcpak file is placed in the parent
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
        $stderr.puts("Warning: No README.txt found.") unless readme.file?
        $stderr.puts("Warning: No levels found.") if spec.levels.empty?
        
        #4. Compress the whole thing
        #The process is as follows: A temporary directory is created, in which
        #a subdirectory that is named after the package is created. The
        #spec, the README and the levels, music, etc. are then copied into
        #that subdirectory which in turn is then compressed. The resulting
        #.smcpak file is copied back to the original directory’s parent dir.
        #After that, the mktmpdir block ends and deletes the temporary
        #directory.
        path = Dir.mktmpdir("smc-get-create-#{pkg_name}") do |tmpdir|
          goal_dir = Pathname.new(tmpdir) + pkg_name
          goal_dir.mkdir
          
          FileUtils.cp(spec_file, goal_dir)
          FileUtils.cp(readme, goal_dir)
          [:levels, :graphics, :music, :sounds, :worlds].each do |sym|
            #4.1. Create the group’s subdir
            dirname = const_get(:"#{sym.upcase}_DIR")
            goal_group_dir = goal_dir + dirname
            goal_group_dir.mkdir
            #4.2. Copy all the group’s files over to it
            spec[sym].each do |filename|
              FileUtils.cp(directory + dirname + filename, goal_group_dir)
            end
          end
          #4.3. actual compression
          PackageArchive.compress(goal_dir, smcpak_file).path
        end
        #5. Return a new instance of Package
        from_file(path)
      end
      
    end
    
    #Creates a new Package from the given specification file. The
    #+pkg_location+ can either be a string or Pathname (creating a local
    #package) or a Repository object (either RemoteRepository or
    #LocalRepository, causing a remote package). You shouldn’t use this method
    #directly, because you would have to download the specification file
    #manually when creating a remote package, so stick to the from_file and
    #from_repository class methods.
    def initialize(spec_file, pkg_location)
      @spec = PackageSpecification.from_file(spec_file)
      @location = pkg_location
    end
    
    #Downloads the package from the remote repository and places it in
    #+directory+. Returns a new Package instance which is a local
    #package refering to the downloaded file. If a block is given, yields
    #the number of bytes to fetch and how many bytes have already been fetched.
    def fetch(directory, &block) # :yields: bytes_total, bytes_done
      raise(Errors::SmcGetError, "This is already a local package!") unless remote?
      path = @location.fetch_package(@spec.pkg_name, directory, &block)
      self.class.from_file(path)
    end
    
    #Does the same as #fetch, but turns this instance into a local package
    #object instead of returning a new object. Returns the path to the
    #downloaded package file.
    def fetch!(directory, &block) # :yields: bytes_total, bytes_done
      raise(Errors::SmcGetError, "This is already a local package!") unless remote?
      path = @location.fetch_package(@spec.pkg_name, directory, &block)
      @location = path
    end
    
    #Returns a truth value if this package resides in a repository
    #(attention: A local repository is a repository, too!).
    def remote?
      @location.kind_of?(Repository)
    end
    
    #Returns a truth value if this packages is a bare file on your
    #computer.
    def local?
      !remote?
    end
    
    #Decompresses this package into +directory+, creating a subdirectory
    #named after the archive without the extension, and returns the path
    #to that subdirectory (a Pathname object).
    #
    #This method is of course only available for local packages, so you may
    #have to call #fetch or #fetch!.
    def decompress(directory)
      raise(Errors::SmcGetError, "Only local packages can be decompressed!") if remote?
      
      PackageArchive.new(@location).decompress(directory)
    end
    
    def inspect
      "#<#{self.class} #{@spec.name} (#{remote? ? 'remote' : 'local'})>"
    end
    
  end
  
end
