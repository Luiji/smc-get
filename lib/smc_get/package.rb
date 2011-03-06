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
  
  #An object of this class represents a package. Wheather it is installed or
  #not, doesn't matter (call #installed? to find out), but everything you
  #want to manage your packages can be found here. For example, to install
  #a remote package, do:
  #  pkg = SmcGet::Package.new("mypackage")
  #  pkg.install
  #Don't forget to set up smc-get before you use the library:
  #  require "smc_get/"
  #  SmcGet.setup(
  #    "https://github.com/Luiji/Secret-Maryo-Chronicles-Contributed-Levels/raw/master/",
  #    "dir/where/you/hava/smc/installed"
  #  end
  class Package
    
    #The package specification file for this packages. This file may not
    #exist if the package is not installed. This is a Pathname object.
    attr_reader :spec_file
    #The name of this package.
    attr_reader :name
    
    class << self
      
      #Searches through the package repostitory and returns an array
      #of matching package objects.
      #
      #Pass in the regular expression to search for (or a string, which
      #then is treated as a regular expression without anchors), the
      #keys of the specification to search through as an array of symbols,
      #and wheather you want to query only locally installed packages (by
      #default, only remote packages are searched).+query_fields+ indicates
      #which fields of the package specification shall be searched. You can
      #pass them as an array of symbols. +only_local+ causes smc-get to
      #do a local search instead of a remote one.
      #
      #With solely :pkgname specified, just the specifications for the packages
      #whose package file names match +regexp+ are downloaded, causing a
      #massive speedup.
      def search(regexp, query_fields = [:pkgname], only_local = false)
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
      
        list.each do |pkg_name|
          pkg = Package.new(pkg_name)
          #If the user wants to query just the pkgname, we can save
          #much time by not downloading all the package specs.
          if query_fields == [:pkgname]
            ary << pkg if pkg_name =~ regexp
          else
            spec = only_local ? pkg.spec : pkg.getinfo
            query_fields.each do |field|
              if field == :pkgname #This field is not _inside_ the spec.
                ary << pkg if pkg_name =~ regexp
              else
                #First to_s: Convert Symbol to string used in the specs.
                #Second to_s: Ensure array values such as "author" are
                #             handled correctly.
                ary << pkg if spec[field.to_s].to_s =~ regexp
              end
            end
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
          Dir.glob("**/*.yml").map{|filename| new(filename.match(/\.yml$/).pre_match)}
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
    
    # Install a package from the repository. Yields the name of the file
    # currently being downloaded, how many percent of that
    # file have already been downloaded and wheather or not this is a retry (if
    # so, the exception object is yielded, otherwise false).
    # The maximum number of retries is specified via the +max_tries+ parameter.
    def install(max_tries = 3) # :yields: file, percent_file, retrying
      try = 1 #For avoiding retrying infinitely
      begin
        SmcGet.download("packages/#{@name}.yml", SmcGet.datadir + PACKAGE_SPECS_DIR + "#{@name}.yml") do |file, percent_done|
          yield(file, percent_done, false) if block_given?
        end
      rescue Errors::DownloadFailedError => e
        if try > max_tries
          File.delete(SmcGet.datadir + PACKAGE_SPECS_DIR + "#{@name}.yml") #There is an empty file otherwise
          if e.class == Errors::ConnectionTimedOutError
            raise #Bubble up
          else
            raise(Errors::NoSuchPackageError.new(@name), "ERROR: Package not found in the repository: #{@name}.")
          end
        else
          try += 1
          yield(e.download_url, 0, e) if block_given?
          retry
        end
      end
      
      pkgdata = YAML.load_file(SmcGet.datadir + PACKAGE_SPECS_DIR + "#{@name}.yml")
      package_parts = [["levels", :level], ["music", :music], ["graphics", :graphic]]
      
      package_parts.each_with_index do |ary, i|
        part, sym = ary
        try = 1
        
        if pkgdata.has_key?(part)
          pkgdata[part].each do |filename|
            begin
              SmcGet.download("#{part}/#{filename}", SmcGet.datadir + SmcGet.const_get(:"PACKAGE_#{part.upcase}_DIR") + filename) do |file, percent_done|
                yield(file, percent_done, false) if block_given?
              end
            rescue Errors::DownloadFailedError => e
              if try > max_tries
                if e.class == Errors::ConnectionTimedOutError
                  raise #Bubble up
                else
                  raise(Errors::NoSuchResourceError.new(sym, error.download_url), "ERROR: #{sym.capitalize} not found in the repository: #{filename}.")
                end
              else
                try += 1
                yield(e.download_url, 0, e) if block_given?
                retry
              end #if try > max_tries
            end #begin
          end #each part
        end #has_key?
      end #each part and sym
    end #install
    
    # Uninstall a package from the local database. If a block is given,
    # it is yielded the package part currently being deleted and
    # how many percent of the files have already been deleted for the current package
    # part.
    def uninstall
      begin
        pkgdata = YAML.load_file(SmcGet.datadir + PACKAGE_SPECS_DIR + "#{@name}.yml")
      rescue Errno::ENOENT
        raise(Errors::NoSuchPackageError.new(@name), "ERROR: Local package not found: #{@name}.")
      end
      
      %w[music graphics levels].each_with_index do |part, part_index|
        if pkgdata.has_key? part
          total_files = pkgdata[part].count
          pkgdata[part].each_with_index do |filename, index|
            begin
              File.delete(SmcGet.datadir + SmcGet.const_get("PACKAGE_#{part.upcase}_DIR") + filename)
            rescue Errno::ENOENT
            end
            yield(part, ((index + 1) / total_files) * 100) if block_given? #+1, because index is 0-based
          end
        end
      end
      
      File.delete(SmcGet.datadir + PACKAGE_SPECS_DIR + "#{@name}.yml")
    end
    
    #Returns true if the package is installed locally. Returns false
    #otherwise.
    def installed?
      SmcGet.datadir.join(PACKAGE_SPECS_DIR, "#{@name}.yml").file?
    end
    
    #Get package information on a remote package. This method never
    #retrieves any information from a locally installed package, look
    #at #spec for that. Return value is the package specification in form
    #of a hash.
    #
    #WARNING: This function is not thread-safe.
    def getinfo
      yaml = nil
      Tempfile.open('pkgdata') do |tmp|
        begin
          SmcGet.download("packages/#{@name}.yml", tmp.path)
        rescue Errors::DownloadFailedError
          raise(Errors::NoSuchPackageError.new(@name), "ERROR: Package not found in the repository: #{@name}")
        end
        yaml = YAML.load_file(tmp.path)
      end
      return yaml
    end
    
    #Retrieves the package specification from a locally installed package
    #in form of a hash. In order to fetch information from a remote package,
    #you have to use the #getinfo method.
    def spec
      if installed?
        YAML.load_file(@spec_file)
      else
        raise(Errors::NoSuchPackageError, "ERROR: Package not installed locally: #@name.")
      end
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