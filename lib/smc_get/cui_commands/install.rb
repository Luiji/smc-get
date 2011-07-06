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
    
    class InstallCommand < Command
      
      def self.help
        <<HELP
USAGE: #{File.basename($0)} install [-r] PACKAGES

Installs one or more packages.

OPTIONS:
  -r\t--reinstall\tForces a reinstallation of the package.
HELP
      end
      
      def self.summary
        "install\tInstall one or more packages."
      end
      
      def parse(args)
        CUI.debug("Parsing #{args.count} args for install.")
        raise(InvalidCommandline, "No package given.") if args.empty?
        @reinstall = false
        @pkg_names = []
        
        until args.empty?
          arg = args.shift
          case arg
          when "--reinstall", "-r" then @reinstall = true
          else
            @pkg_names << arg
            $stderr.puts("Unknown argument #{arg}. Treating it as a package.") if arg.start_with?("-")
          end
        end
      end
      
      def execute(config)
        CUI.debug("Executing install.")
        
        @pkg_names.each do |pkg_name|
          begin
            install_package_with_deps(pkg_name)
          rescue => e
            $stderr.puts(e.message)
            $stderr.puts("Ignoring the problem, continueing with the next package, if any.")
            if CUI.debug_mode?
              $stderr.puts("Class: #{e.class}")
              $stderr.puts("Message: #{e.message}")
              $stderr.puts("Backtrace:")
              $stderr.puts(e.backtrace.join("\n\t"))
            end
          end
        end #each
      end #execute

      private

      #Recursively installs a package and all of it’s dependencies and their dependencies and...
      def install_package_with_deps(pkg_name, dep_list = [], is_dep = false)
        if dep_list.include?(pkg_name)
          $stderr.puts("WARNING: Circular dependency detected, skipping additional #{pkg_name}!")
          return
        end
        dep_list << pkg_name
        
        if @cui.local_repository.contains?(pkg_name)
          if @reinstall
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
        pkg.spec.dependencies.each{|dep| install_package_with_deps(dep, dep_list, true)}

        puts "Installing #{pkg_name}..."
        puts pkg.install_message if pkg.spec.install_message
        @cui.local_repository.install(pkg)
      end
    end
    
  end
  
end

# vim:set ts=8 sts=2 sw=2 et: #
