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
  
  module CUICommands
    
    #Class for invalid command-line argument errors.
    class InvalidCommandline < Errors::SmcGetError
    end
    
    #This is the superclass of all CUI commands. To make your own command,
    #subclass it an overwrite ::help, ::summary, #parse and #execute.
    class Command
      
      #The string returned from this method will be displayed to the
      #user if he issues <tt>smc-get help YOURCOMMAND</tt>.
      def self.help
        "(nothing known)"
      end
      
      #One-line summary of the command that shows up in the COMMANDS
      #section of <tt>smc-get help</tt>. Should not be longer than 78
      #characters due to automatic indentation. You may have to insert
      #tabs to make it display correctly; make sure to check the result by
      #issueing <tt>smc-get help</tt>.
      def self.summary
        ""
      end
      
      #Creates a new instance of this command. Do not override this, or
      #call at least +super+.
      def initialize(cui, args)
        @cui = cui
        parse(args)
      end

      #This method gets all commandline options relevant for this subcommand
      #passed in the +args+ array. You should parse them destructively, i.e.
      #after you finished parsing, +args+ should be an empty array.
      #Set instance variables to save data.
      #
      #Note that SmcGet is not set up when this method is called, so you
      #cannot do things like <tt>Package.new</tt>.
      def parse(args)
        raise(NotImplementedError, "#{__method__} has to be overriden in a subclass!")
      end
      
      #Execute the command. You can use the instance variables set in #parse.
      #The method gets passed the parsed contents of smc-get's configuration
      #files and commandline parameters; you can use this to make your command
      #configurable via the configuration file, but make sure that
      #1. The keys you use for your configuration don't already exist,
      #2. options specified on the commandline take precedence over values
      #   set in the configuration file and
      #3. you <b>do not alter</b> the hash.
      def execute(config)
        raise(NotImplementedError, "#{__method__} has to be overriden in a subclass!")
      end

      private

      #Downloads the package identified by +pkgname+ and displays the progress to the
      #user. Example:
      #  download_package("cool_world")
      #downloads the package "cool_world.smcpak". You mustn’t specify the file
      #extension <tt>.smcpak</tt>.
      def download_package(pkgname)
        pkg_file = "#{pkgname}.smcpak"
        #Windows doesn't understand ANSI escape sequences, so we have to
        #use the carriage return and reprint the whole line.
        base_str = "\rDownloading %s... (%.2f%%)"
        tries = 0
        begin
          tries += 1
          path_to_package = @cui.remote_repository.fetch_package(pkg_file, SmcGet.temp_dir) do |bytes_total, bytes_done|
            percent = ((bytes_done.to_f / bytes_total) * 100)
            print "\r", " " * 80 #Clear everything written before
            printf(base_str, pkg_file, percent)
          end
        rescue OpenURI::HTTPError => e #Thrown even in case of FTP and HTTPS
          if tries >= 3
            raise #Bubble up
          else
            $stderr.puts("ERROR: #{e.message}")
            $stderr.puts("Retrying.")
            retry
          end
        end
        puts #Terminating \n
        return path_to_package
      end

      #Recursively installs a package and all of it’s dependencies and their dependencies and so on.
      #+pkg_name+ doesn’t include the .smcpak file extension. The +dep_list+ argument is filled
      #during the recursion with all encountered package to prevent endless recursion in case
      #of circular dependencies and +is_dep+ determines during the recursion wheather or not
      #the currently checked package is to be treated as a dependency (used to
      #spit out a note on --reinstall if the package is already installed). +reinstall+ determines
      #wheather or not a package already installed shall be reinstalled (this affects the dependencies
      #as well).
      def install_package_with_deps(pkg_name, reinstall = false, dep_list = [], is_dep = false)
        if dep_list.include?(pkg_name)
          $stderr.puts("WARNING: Circular dependency detected, skipping additional #{pkg_name}!")
          return
        end
        dep_list << pkg_name
        
        if @cui.local_repository.contains?(pkg_name)
          if reinstall
            puts "Reinstalling #{pkg_name}."
          else
            puts "#{pkg_name} is already installed. Maybe you want --reinstall?" unless is_dep
            return
          end
        end

        puts "Downloading #{pkg_name}..."
        path = download_package(pkg_name)
        pkg = Package.from_file(path)

        puts "Resolving dependencies for #{pkg_name}..."
        pkg.spec.dependencies.each{|dep| install_package_with_deps(dep, reinstall, dep_list, true)}

        puts "Installing #{pkg_name}..."
        puts pkg.spec.install_message if pkg.spec.install_message
        @cui.local_repository.install(pkg)
      end

      #Removes a package from the local repository. +pkg_name+ is the name of the
      #package without any file extension, +ignore_deps+ determines wheather or not
      #to uninstall even if other packages depend on the target and +ignore_conflicts+
      #indicates wheather to prompt the user for action if a modified file is
      #encountered (if set to true, modified files are deleted).
      def uninstall_package(pkg_name, ignore_deps = false, ignore_conflicts = false)
        #Check if a dependency conflict exists
        unless ignore_deps
          puts "Checking for dependencies on #{pkg_name}..."
          specs = @cui.local_repository.package_specs.reject{|spec| spec.name == pkg_name} #A package ought to not depend on itself
          if (i = specs.index{|spec| spec.dependencies.include?(pkg_name)}) #Single equal sign intended
            puts "The package #{specs[i].name} depends on #{pkg_name}."
            print "Remove it anyway?(y/n) "
            raise(Errors::BrokenPackageError, "Can't uninstall #{pkg_name} due to dependency reasons!")  unless $stdin.gets.chomp == "y"
          end
        end
        #Real remove operation
        puts "Removing files for #{pkg_name}..."
        @cui.local_repository.uninstall(pkg_name) do |conflict|
          next(false) if ignore_conflicts
          puts "CONFLICT: The file #{conflict} has been modified. What now?"
          puts "1) Ignore and delete anyway"
          puts "2) Copy file and include MODIFIED in the name."
          print "Enter a number[1]: "
          $stdin.gets.chomp.to_i == 2 #True means copying
        end
      end
      
    end
    
  end
  
end

# vim:set ts=8 sts=2 sw=2 et: #
