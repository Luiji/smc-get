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
USAGE: #{File.basename($0)} install [-l][-r] PACKAGES

Installs one or more packages.

OPTIONS:
  -l\t--local\t\tInstalls a package from the local filesystem.
  \t\t\tPACKAGES are treated as file paths.
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
        @local = false
        @pkg_names = []
        
        until args.empty?
          arg = args.shift
          case arg
          when "--local", "-l" then @local = true
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
            if @local
              pkg = Package.from_file(pkg_name)
              if @cui.local_repository.contains?(pkg) and !@reinstall
                puts "#{pkg.spec.name} is already installed. Maybe you want --reinstall?"
                next
              end
              puts "Resolving dependencies for #{pkg.spec.name}..."
              pkg.spec.dependencies.each{|dep| install_package_with_deps(dep, @reinstall, [], true)}
              puts "Installing #{pkg.spec.name} from local file..."
              puts pkg.spec.install_message if pkg.spec.install_message
              @cui.local_repository.install(pkg)
            else
              install_package_with_deps(pkg_name, @reinstall)
            end
          rescue => e
            $stderr.puts(e.message)
            $stderr.puts("Ignoring the problem, continueing with the next package, if any.")
            if CUI.debug_mode?
              $stderr.puts("Class: #{e.class}")
              $stderr.puts("Message: #{e.message}")
              $stderr.puts("Backtrace:")
              $stderr.puts(e.backtrace.join("\n\t"))
            end #if debug mode
          end #begin
        end #each
      end #execute
      
    end
    
  end
  
end

# vim:set ts=8 sts=2 sw=2 et: #
