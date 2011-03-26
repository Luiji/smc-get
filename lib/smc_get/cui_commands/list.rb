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
    
    class ListCommand < Command
      
      def self.help
        <<EOF
USAGE: #{File.basename($0)} list [PACKAGE]

If PACKAGE is given, lists all files installed by PACKAGE. Otherwise,
all installed packages are listed accompanied by their installation
date in the format YY-MM-DD HH:MM, where the time is given on a
24-hour clock.
EOF
      end
      
      def self.summary
        "list\t\tLists all installed packages or files installed by a package. "
      end
      
      def parse(args)
            CUI.debug("Parsing #{args.count} args for list.")
        raise(InvalidCommandline, "Too many arguments.") if args.count > 1
        @pkg_name = args.shift #nil if not specified
      end
      
      def execute(config)
        CUI.debug("Executing help.")
        if Package.installed_packages.empty?
          puts "No packages installed."
        else
          if @pkg_name
            pkg = Package.new(@pkg_name)
            puts "Files installed for #{pkg}:"
            info = pkg.spec
            puts
            puts "Levels:"
            puts info["levels"].join("\n")
            puts
            puts "Music:"
            puts info.has_key?("music") ? info["music"].join("\n") : "(None)"
            puts
            puts "Graphics:"
            puts info.has_key?("graphics") ? info["graphics"].join("\n") : "(None)"
          else
            printf("%-38s | %-38s\n", "Package", "Installation date")
            print("-" * 39, "+", "-" * 40, "\n")
            Package.installed_packages.each do |pkg|
              printf("%-38s | %-38s\n", pkg.name, pkg.spec_file.mtime.strftime("%d-%m-%Y %H:%M"))
            end
          end
        end
      end
      
    end
    
  end
  
end
# vim:set ts=8 sts=2 sw=2 et: #