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
    
    #Creates a new package object from it's name. This doesn't do anything,
    #especially it doesn't install the package. It just creates an object for
    #you you can use to inspect or install pacakges. It doesn't even check if
    #the package name is valid.
    def initialize(package_name)
      Errors::LibraryNotInitialized.throw_if_needed!
      @package_name = package_name
      @spec_file = SmcGet.datadir.join(PACKAGE_SPECS_DIR, "#{@package_name}.yml")
    end
    
    # Install a package from the repository. Yields the total progress in percent,
    # the name of the file currently being downloaded and how many percent of that
    # file have already been downloaded.
    def install
      percent_total = 0 #For reporting the total progress
      begin
        SmcGet.download(
        "packages/#{@package_name}.yml",
        SmcGet.datadir + PACKAGE_SPECS_DIR + "#{@package_name}.yml"
        ) do |file, percent_done|
          yield(percent_total, file, percent_done) if block_given?
        end
      rescue Errors::DownloadFailedError
        File.delete(SmcGet.datadir + PACKAGE_SPECS_DIR + "#{@package_name}.yml") #There is an empty file otherwise
        raise(Errors::NoSuchPackageError.new(@package_name), "ERROR: Package not found in the repository: #{@package_name}.")
      end
      
      pkgdata = YAML.load_file(SmcGet.datadir + PACKAGE_SPECS_DIR + "#{@package_name}.yml")
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
        pkgdata = YAML.load_file(SmcGet.datadir + PACKAGE_SPECS_DIR + "#{@package_name}.yml")
      rescue Errno::ENOENT
        raise(Errors::NoSuchPackageError.new(@package_name), "ERROR: Local package not found: #{@package_name}.")
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
      
      File.delete(SmcGet.datadir + PACKAGE_SPECS_DIR + "#{@package_name}.yml")
    end
    
    #Returns true if the package is installed locally. Returns false
    #otherwise.
    def installed?
      SmcGet.datadir.join(PACKAGE_SPECS_DIR, "#{@package_name}.yml").file?
    end
    
    # Get package information.  WARNING: This function is not thread-safe.
    def getinfo(force_remote = false)
      yaml = nil
      if force_remote or !installed?
        Tempfile.open('pkgdata') do |tmp|
          begin
            SmcGet.download("packages/#{@package_name}.yml", tmp.path)
          rescue Errors::DownloadFailedError
            raise(Errors::NoSuchPackageError.new(@package_name), "ERROR: Package not found in the repository: #{@package_name}")
          end
          yaml = YAML.load_file(tmp.path)
        end
      else
        yaml = YAML.load_file(SmcGet.datadir + PACKAGE_SPECS_DIR + "#{@package_name}.yml")
      end
      return yaml
    end
    
    #Returns the name of the package.
    def to_s
      @package_name
    end
    
    #Human-readable description of form
    #  #<SmcGet::Package package_name (installation_status)>
    def inspect
      "#<#{self.class} #{@package_name} (#{installed? ? 'installed' : 'not installed'})>"
    end
    
  end
  
end