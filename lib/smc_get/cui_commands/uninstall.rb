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
          pkg = Package.new(pkg_name)
          puts "Uninstalling #{pkg}."
          unless pkg.installed?
            $stderr.puts "#{pkg} is not installed. Skipping."
            next
          end
          #Windows doesn't understand ANSI escape sequences, so we have to
          #use the carriage return and reprint the whole line.
          base_str = "\rRemoving %s... (%.2f%%)"
          pkg.uninstall do |part, percent_part|
            print "\r", " " * 80 #Clear everything written before
            printf(base_str, part, percent_part)
          end
          puts
        end
      end
      
    end
    
  end
  
end
# vim:set ts=8 sts=2 sw=2 et: #