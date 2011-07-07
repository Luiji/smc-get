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
    
    class UpdateCommand < Command
      
      def self.help
        <<EOF
USAGE: #{File.basename($0)} update [PACKAGES...]

Checks for updates in the repository and tries to update the local
packages. If you modified a package, you will be prompted to
decide how to proceed.

OPTIONS:
-y\t--yes\tAssume yes on all queries
EOF
      end
      
      def self.summary
        "update\tUpdate packages."
      end
      
      def parse(args)
        CUI.debug("Parsing #{args.count} args for update.")
        @packages = []
        @assume_yes = false
        while(arg = args.shift)
          case arg
          when "-y", "--yes" then @assume_yes = true
          else
            @packages << arg
          end
        end
        #Warn on package names starting with a hyphen, may be a mistyped option
        @packages.each{|pkg| $stderr.puts("Warning: Treating #{pkg} as a package") if pkg.start_with?("-")}
      end
      
      def execute(config)
        CUI.debug("Executing update")

        #Get the packages we want to update
        if @packages.empty? #None given, default to all
          packages = @cui.local_repository.package_specs.map(&:name)
        else
          packages = @packages
        end
        puts "Going to check #{packages.count} packages for updates."
        
        packages.each do |pkgname|
          spec_name = "#{pkgname}.yml"
          local_spec = PackageSpecification.from_file(@cui.local_repository.fetch_spec(spec_name))
          remote_spec = PackageSpecification.from_file(@cui.remote_repository.fetch_spec(spec_name))

          #Execute update if remote is newer than local
          if remote_spec.last_update > local_spec.last_update

            puts "Updating #{pkgname}."
            begin
              #First uninstall the old version--this is necessary, b/c a new
              #version of a package may have files removed that wouldn’t be
              #deleted by a simple overwrite operation.
              puts "Uninstalling obsolete version of #{pkgname}... "
              uninstall_package(pkgname, true, @assume_yes) #We ignore dependencies as we immediately reinstall a package
              
              #Then install the new version.
              install_package_with_deps(pkgname, @assume_yes)
            rescue => e
              $stderr.puts(e.message)
              $stderr.puts("Ignoring the problem and continuing with the next package, if any.")
              if CUI.debug_mode?
                $stderr.puts("Class: #{e.class}")
                $stderr.puts("Message: #{e.message}")
                $stderr.puts("Backtrace:")
                $stderr.puts(e.backtrace.join("\n\t"))
              end
            end
          end
        end
      end
      
    end
    
  end
  
end
# vim:set ts=8 sts=2 sw=2 et: #
