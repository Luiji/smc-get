#Encoding: UTF-8

module SmcGet
  
  class LocalRepository < Repository
    
    #Directory where the package specs are kept.
    SPECS_DIR            = Pathname.new("packages")
    #Directory where downloaded packages are cached.
    CACHE_DIR            = Pathname.new("cache")
    #Directory where the packages’ level files are kept.
    CONTRIB_LEVELS_DIR   = Pathname.new("levels") #Levels in subdirectories are currently not recognized by SMC
    #Directory where the packages’ music files are kept.
    CONTRIB_MUSIC_DIR    = Pathname.new("music") + "contrib_music"
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
    #All packages that are installed in this repository. An array of
    #InstalledPackage objects.
    attr_reader :packages
    
    def initialize(path)
      @path         = Pathname.new(path)
      @specs_dir    = @path + SPECS_DIR
      @cache_dir    = @path + CACHE_DIR
      @levels_dir   = @path + CONTRIB_LEVELS_DIR
      @music_dir    = @path + CONTRIB_MUSIC_DIR
      @graphics_dir = @path + CONTRIB_GRAPHICS_DIR
      @sounds_dir   = @path + CONTRIB_SOUNDS_DIR
      @worlds_dir   = @path + CONTRIB_WORLDS_DIR
      
      @packages = []
      @specs_dir.children.each do |spec_path|
        next unless spec_path.to_s.end_with?(".yml")
        @packages << Package.from_repository(self, spec_path)
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
      package = package.fetch(SmcGet.temp_dir, &block) if package.remote?
      
      path = package.decompress(SmcGet.temp_dir)
      
      FileUtils.cp(path + package.spec.path.basename, @specs_dir)
      
      FileUtils.cp(path.join(Package::LEVELS_DIR), @levels_dir)
      FileUtils.cp(path.join(Package::MUSIC_DIR), @music_dir)
      FileUtils.cp(path.join(Package::GRAPHICS_DIR), @graphics_dir)
      FileUtils.cp(path.join(Package::SOUNDS_DIR), @sounds_dir)
      FileUtils.cp(path.join(Package::WORLDS_DIR), @worlds_dir)
      
      FileUtils.cp(package.location, @cache_dir)
    end
    
    def uninstall(pkg_name)
      pkg = @packages.find{|pkg| pkg.spec.name == pkg_name}
      
      [:levels, :music, :sounds, :graphics, :worlds].each do |sym|
        contrib_dir = self.class.const_get(:"CONTRIB_#{sym.upcase}_DIR")
        
        #Delete all the files
        files = pkg.spec.send(sym)
        files.each do |filename|
          File.delete(contrib_dir + filename)
        end
        
        #Delete now empty directories
        loop do
          empty_dirs = []
          contrib_dir.find do |path|
            next if path.basename == contrib_dir #We surely don’t want to delete the toplevel dir.
            empty_dirs << path if path.directory? path.children.empty?
          end
          #If no empty directories are present anymore, break out of the loop.
          break if empty_dirs.empty?
          #Otherwise delete the empty directories and redo the process, because
          #the parent directories could be empty now.
          empty_dirs.each{|path| File.delete(path)}
        end
      end
      
    end
    
    def contain?(pkg_name)
      @packages.any?{|pkg| pkg.spec.name == pkg_name}
    end
    alias contains? contain?
    
  end
  
end
