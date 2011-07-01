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
    
    class UninstallCommand < Command
      
      def self.help
        <<EOF
#{File.basename($0)} uninstall PACKAGES

Removes PACKAGES from your set of downloaded packages.
EOF
      end
      
      def self.summary
        "uninstall\tUninstalls one or more packages."
      end
      
      def parse(args)
        CUI.debug("Parsing #{args.count} args for uninstall.")
        raise(InvalidCommandline, "No package given.") if args.empty?
        @pkg_names = []
        until args.empty?
          arg = args.shift
          #case arg
          #when "-c", "--my-arg" then ...
          #else
          @pkg_names << arg
          $stderr.puts("Unkown argument #{arg}. Treating it as a package.") if arg.start_with?("-")
          #end
        end
      end
      
      def execute(config)
        CUI.debug("Executing uninstall.")
        @pkg_names.each do |pkg_name|
          if @cui.local_repository.contains?(pkg_name)
            spec = PackageSpecification.from_file(@cui.local_repository.fetch_spec("#{pkg_name}.yml", SmcGet.temp_dir))
            puts spec.remove_message if spec.remove_message
            print "Removing #{pkg_name}... "
            @cui.local_repository.uninstall(pkg_name)
            puts "Done."
          else
            $stderr.puts "#{pkg_name} is not installed. Skipping."
          end
        end
      end
      
    end
    
  end
  
end
# vim:set ts=8 sts=2 sw=2 et: #
