#!/usr/bin/env ruby
#Encoding: UTF-8

module SmcGet
  
  #A RemoteRepository represents a web location from which <tt>smc-get</tt>
  #is able to download packages. The structure of those repositories is
  #explained in the smcpak.rdoc file in the <i>Repostories</i> section.
  class RemoteRepository < Repository
    
    #Name of the remote directory containing the <tt>.smcpak</tt> files.
    PACKAGES_DIR = "packages"
    #Name of the remote directory containing the packages specifications.
    SPECS_DIR    = "specs"
    #Name of the file containg the names of all packages in this repository.
    LIST_FILE    = "packages.lst"
    #Number of bytes to read while downloading a file.
    CHUNK_SIZE   = 1024
    
    ##
    # :attr_reader: packages
    #Returns an array of remote Packages that contains all packages
    #in this repository. This is a very time-intensive operation, depending
    #on how many packages the repository contains, because it downloads all
    #the package specifications of all the packages. It’s not a good idea
    #to call this.
    
    #An URI object representing the repository’s URI.
    attr_reader :uri
    #A list of all package names (without an extension).
    attr_reader :packages_list
    
    #Creates a "new" Repository.
    #==Parameters
    #[uri] The URI of the repository, something like
    #      "\http://my-host.org/smc-repo".
    #==Raises
    #[InvalidRepository] The repository is either nonexistant or doesn’t obey
    #                    the repository structure format.
    #==Return value
    #The newly created repository.
    #==Usage
    #  r = Repository.new("http://myrepo.org")
    #  r = Repository.new("https://my-host.org/smc-repo")
    #  r = Repository.new("ftp://ftp.my-host.org/smc")
    def initialize(uri)
      @uri = URI.parse(uri)
      #Download the packages list. Usually it’s small enough to fit into RAM.
      begin
        @packages_list = open(@uri + LIST_FILE){|tmpfile| tmpfile.read}.split
      rescue SocketError, OpenURI::HTTPError => e #open-uri raises HTTPError even in case of other protocols
        raise(InvalidRepository.new(@uri), "ERROR: #{e.message}")
      end
    end
    
    #Downloads the given package specification from this repository and
    #places it in +directory+.
    #
    #If the file already exists, it’s overwritten.
    #==Parameters
    #[spec_file] The package specification file you want to download. It must
    #            end with the <tt>.yml</tt> extension.
    #[directory] (".") The directory where you want to download the file to.
    #            Created if it doesn’t exist.
    #==Raises
    #[NoSuchResourceError] The package name for this specification couldn’t be
    #                      found in the repository. Note that the spec may be
    #                      there despite of this, but packages not listed
    #                      in the repository’s contents file are treated as if
    #                      they weren’t there.
    #==Return value
    #The path to the downloaded file as a Pathname object.
    #==Usage
    #  my_repo.fetch_spec("mypackage.yml", "/home/freak/Downloads")
    #
    #  my_repo.fetch_spec("mypackage.yml")
    def fetch_spec(spec_file, directory = ".")
      directory = Pathname.new(directory)
      pkg_name = spec_file.sub(/\.yml$/, "")
      goal_file = directory + spec_file
      
      unless @packages_list.include?(pkg_name)
        raise(NoSuchResourceError.new(:spec, spec_file), "ERROR: Package '#{pkg_name}' not found in the repository!")
      end
      
      directory.mktree unless directory.directory?
      
      open(@uri + SPECS_DIR + spec_file) do |tempfile|
        File.open(goal_file, "w") do |file|
          file.write(tempfile.read) #Specs almost ever are small enough to fit in RAM
        end
      end
      goal_file
    end
    
    #Downloads the given package from this repository and places it in
    #+directory+. Yields the package’s total size in bytes and how many
    #bytes have already been downloaded. If the size is unknown for some
    #reason, +bytes_total+ is nil. For the last block call, +bytes_total+
    #and +bytes_done+ are guaranteed to be equal, except if +bytes_total+
    #couldn’t be determined in which case it’s still nil.
    #
    #If the file does already exist in +directory+, it is overwritten.
    #==Parameters
    #[pkg_file]  The package file you want to download. It must end in
    #            the <tt>.smcpak</tt> extension.
    #[directory] (".") The directory where you want to download the file to.
    #            Created if it doesn’t exist.
    #==Raises
    #[NoSuchPackageError] The package name for this package couldn’t be
    #                     found in the repository. Note that the package may be
    #                     there despite of this, but packages not listed
    #                     in the repository’s contents file are treated as if
    #                     they weren’t there.
    #==Return value
    #The path to the downloaded file as a Pathname object.
    #==Usage
    #  my_repo.fetch_package("mypackage.smcpak", "/home/freak/downloads")
    #
    #  my_repo.fetch_package("mypackage.smcpak") do |bytes_total, bytes_done|
    #    print("\rDownloaded #{bytes_done} bytes of #{bytes_total}.") if bytes_total
    #  end
    def fetch_package(pkg_file, directory = ".")
      directory = Pathname.new(directory)
      pkg_name = spec_file.sub(/\.smcpak$/, "")
      goal_file = directory + pkg_file
      
      unless @packages_list.include?(pkg_name)
        raise(NoSuchPackageError.new(pkg_name), "ERROR: Package '#{pkg_name}' not found in the repository!")
      end
      
      directory.mktree unless directory.directory?
      
      bytes_total = nil
      size_proc = lambda{|content_length| bytes_total = content_length}
      prog_proc = lambda{|bytes_done| yield(bytes_total, bytes_done)}
      
      open(@uri + PACKAGES_DIR + pkg_file, "rb", content_length_proc: size_proc, progress_proc: prog_proc) do |tempfile|
        #The packages may be too big for fitting into RAM, therefore we’re going
        #to read and write the packages chunk by chunk. Btw. please notice me
        #if you find a SMC package that’s larger than 4 GiB! I’d be curious
        #about what it contains!
        File.open(goal_file, "wb") do |file|
          while chunk = tempfile.read(CHUNK_SIZE)
            file.write(chunk)
          end
        end
      end
      
      goal_file
    end
    
    #Not implemented yet.
    def install(package, &block)
      raise(NotImplementedError, "Can't automatically upload to remote repositories yet!")
    end
    
    #Not implemented yet.
    def uninstall(pkg_name)
      raise(NotImplementedError, "Can't automatically remove from remote repositories yet!")
    end
    
    #See attribute.
    def packages # :nodoc:
      @packages_list.map do |pkg_name|
        Package.from_repository(self, "#{pkg_name}.yml")
      end
    end
    
  end
  
end