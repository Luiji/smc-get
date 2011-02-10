#!/usr/bin/env ruby
#Encoding: UTF-8

module SmcGet
  
  #An object of this class represents a package. Wheather it is installed or
  #not, doesn't matter (call #installed? to find out), but everything you
  #want to manage your packages can be found here. For example, to install
  #a remote package, do:
  #  pkg = SmcGet::Package.new("mypackage")
  #  pkg.install
  #Don't forget to set up smc-get before you use the library:
  #  require "smc_get/smc_get"
  #  SmcGet.datadir = "dir/where/you/hava/smc/installed"
  #  SmcGet.repo_url = "https://github.com/Luiji/Secret-Maryo-Chronicles-Contributed-Levels/raw/master/
  class Package
    
    #The package specification file for this packages. This file may not
    #exist if the package is not installed. This is a Pathname object.
    attr_reader :spec_file
    #The name of this package.
    attr_reader :name
    
    class << self
      
      #Searches through the package repostitory and returns an array
      #of matching package specifications as follows:
      #  [[package_name, package_spec_hsh]]
      #where the +package_spec_hsh+ is just the YAML-parsed package
      #specification.
      #
      #Pass in the regular expression to search for (or a string, which
      #then is treated as a regular expression without anchors), the
      #keys of the specification to search through as an array of symbols,
      #and wheather you want to query only locally installed packages (by
      #default, only remote packages are searched).
      #
      #Note that it's a bad idea to not search for :title, because in remote
      #mode (i.e. <tt>only_local == false</t>, the default setting) smc-get
      #needs to download the package specifications for each and every
      #package in the repository then, which can take quite a long time.
      #With :title, just the specifications for the packages whose titles
      #match +regexp+ are downloaded.
      def search(regexp, query_fields = [:title, :description], only_local = false)
        regexp = Regexp.new(Regexp.escape(regexp)) if regexp.kind_of? String
        ary = []
        
        list = if only_local
          Errors::LibraryNotInitialized.throw_if_needed!
          installed_packages.map(&:name)
        else
          Tempfile.open("smc-get") do |listfile|
            SmcGet.download(PACKAGE_LIST_FILE, listfile.path)
            listfile.readlines.map(&:chomp)
          end
        end
        #TODO: Package name and title are not identical
        if query_fields.include?(:title)
          list.grep(regexp).each do |result|
            search_pkg_spec(result, regexp, query_fields){|spec| ary << [result, spec]}
          end
        else #In case of remote lookup, whe have to download ALL specs then...
          list.each do |result|
            search_pkg_spec(result, regexp, query_fields){|spec| ary << [result, spec]}
          end
        end
        ary
      end
      
      #Returns a list of all currently installed packages as an array of
      #Package objects.
      def installed_packages
        Errors::LibraryNotInitialized.throw_if_needed!
        specs_dir = SmcGet.datadir + PACKAGE_SPECS_DIR
        specs_dir.mkpath unless specs_dir.directory?
        
        #We need to chdir here, because Dir.glob returns the path
        #relative to the current working directory and it should be
        #a bit more performant if I don't have to strip off the relative
        #prefix of the filenames (which are the names of the packages + .yml).
        Dir.chdir(specs_dir.to_s) do
          Dir.glob("*.yml").map{|filename| new(filename.match(/\.yml$/).pre_match)}
        end
      end
      
      private
      
      #Downloads the specification for the package +pkg_name+ and
      #searches through it by matching all keys found in +query_fields+
      #against +regexp+. Matching package specifications are yielded.
      def search_pkg_spec(pkg_name, regexp, query_fields)
        Tempfile.open("smc-get") do |file|
          SmcGet.download("packages/#{pkg_name}.yml", file.path)
          hsh = YAML.load(file.read)
          
          query_fields.each do |field|
            if hsh[field.to_s] =~ regexp ##to_s, because the spec uses strings, not symbols
              yield(hsh)
            end
          end
        end
      end
      
    end
    
    #Creates a new package object from it's name. This doesn't do anything,
    #especially it doesn't install the package. It just creates an object for
    #you you can use to inspect or install pacakges. It doesn't even check if
    #the package name is valid.
    def initialize(package_name)
      Errors::LibraryNotInitialized.throw_if_needed!
      @name = package_name
      @spec_file = SmcGet.datadir.join(PACKAGE_SPECS_DIR, "#{@name}.yml")
    end
    
    # Install a package from the repository. Yields the total progress in percent,
    # the name of the file currently being downloaded and how many percent of that
    # file have already been downloaded.
    def install
      percent_total = 0 #For reporting the total progress
      begin
        SmcGet.download(
        "packages/#{@name}.yml",
        SmcGet.datadir + PACKAGE_SPECS_DIR + "#{@name}.yml"
        ) do |file, percent_done|
          yield(percent_total, file, percent_done) if block_given?
        end
      rescue Errors::DownloadFailedError
        File.delete(SmcGet.datadir + PACKAGE_SPECS_DIR + "#{@name}.yml") #There is an empty file otherwise
        raise(Errors::NoSuchPackageError.new(@name), "ERROR: Package not found in the repository: #{@name}.")
      end
      
      pkgdata = YAML.load_file(SmcGet.datadir + PACKAGE_SPECS_DIR + "#{@name}.yml")
      percent_total = 25 #%
      
      if pkgdata.has_key?('music')
        pkgdata['music'].each do |filename|
          begin
            SmcGet.download(
            "music/#{filename}",
            SmcGet.datadir + PACKAGE_MUSIC_DIR + filename
            ) do |file, percent_done|
              yield(percent_total, file, percent_done) if block_given?
            end
          rescue Errors::DownloadFailedError => error
            raise(Errors::NoSuchResourceError.new(:music, error.download_url), "ERROR: Music not found in the repository: #{filename}.")
          end
        end
      end
      
      percent_total = 50 #%
      
      if pkgdata.has_key?('graphics')
        pkgdata['graphics'].each do |filename|
          begin
            SmcGet.download(
            "graphics/#{filename}",
            SmcGet.datadir + PACKAGE_GRAPHICS_DIR + filename
            ) do |file, percent_done|
              yield(percent_total, file, percent_done) if block_given?
            end
          rescue Errors::DownloadFailedError => error
            raise(Errors::NoSuchResourceError.new(:graphic, error.download_url), "ERROR: Graphic not found in the repository: #{filename}.")
          end
        end
      end
      
      percent_total = 75 #%
      
      if pkgdata.has_key?('levels')
        pkgdata['levels'].each_with_index do |filename, index|
          begin
            SmcGet.download(
            "levels/#{filename}",
            SmcGet.datadir + PACKAGE_LEVELS_DIR + filename
            ) do |file, percent_done|
              #The last value the user shall see are 100%, so in the last
              #iteration we set percent_total to 100.
              percent_total = 100 if index == pkgdata["levels"].count - 1 #Index is 0-based
              yield(percent_total, file, percent_done) if block_given?
            end
          rescue Errors::DownloadFailedError => error
            raise(Errors::NoSuchResourceError.new(:level, error.download_url), "ERROR: Level not found in the repository: #{filename}.")
          end
        end
      end
    end
    
    # Uninstall a package from the local database. If a block is given,
    # it is yielded the total progress in percent, the package part currently being deleted, and
    # how many percent of the files have already been deleted for the current package
    # part.
    def uninstall
      begin
        pkgdata = YAML.load_file(SmcGet.datadir + PACKAGE_SPECS_DIR + "#{@name}.yml")
      rescue Errno::ENOENT
        raise(Errors::NoSuchPackageError.new(@name), "ERROR: Local package not found: #{@name}.")
      end
      
      percent_total = 0 #For reporting the total progress
      
      %w[music graphics levels].each_with_index do |part, part_index|
        if pkgdata.has_key? part
          total_files = pkgdata[part].count
          pkgdata[part].each_with_index do |filename, index|
            begin
              File.delete(SmcGet.datadir + SmcGet.const_get("PACKAGE_#{part.upcase}_DIR") + filename)
            rescue Errno::ENOENT
            end
            #The last value the user shall see is 100%, so set it in
            #the very last (i.e. last of the outer and inner loop) iteration
            #to 100.
            percent_total = 100 if part_index == 2 and index == total_files - 1
            yield(percent_total, part, ((index + 1) / total_files) * 100) if block_given? #+1, because index is 0-based
          end
        end
        percent_total = ((part_index + 1) / 3.0) * 100 #+1, because index is 0-based (3 is the total number of iterations)
      end
      
      File.delete(SmcGet.datadir + PACKAGE_SPECS_DIR + "#{@name}.yml")
    end
    
    #Returns true if the package is installed locally. Returns false
    #otherwise.
    def installed?
      SmcGet.datadir.join(PACKAGE_SPECS_DIR, "#{@name}.yml").file?
    end
    
    # Get package information.  WARNING: This function is not thread-safe.
    def getinfo(force_remote = false)
      yaml = nil
      if force_remote or !installed?
        Tempfile.open('pkgdata') do |tmp|
          begin
            SmcGet.download("packages/#{@name}.yml", tmp.path)
          rescue Errors::DownloadFailedError
            raise(Errors::NoSuchPackageError.new(@name), "ERROR: Package not found in the repository: #{@name}")
          end
          yaml = YAML.load_file(tmp.path)
        end
      else
        yaml = YAML.load_file(SmcGet.datadir + PACKAGE_SPECS_DIR + "#{@name}.yml")
      end
      return yaml
    end
    
    #Returns the name of the package.
    def to_s
      @name
    end
    
    #Human-readable description of form
    #  #<SmcGet::Package package_name (installation_status)>
    def inspect
      "#<#{self.class} #{@name} (#{installed? ? 'installed' : 'not installed'})>"
    end
    
  end
  
end