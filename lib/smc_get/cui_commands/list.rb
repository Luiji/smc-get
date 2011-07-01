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
all installed packages are listed accompanied by their last-update
date in the format DD-MM-YYYY HH:MM, where the time is given on a
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
        CUI.debug("Executing list")
        if @pkg_name
          spec = PackageSpecification.from_file(@cui.local_repository.fetch_spec("#{@pkg_name}.yml", SmcGet.temp_dir))
          puts "Files installed for #{spec.name}:"
          puts "====================#{'=' * spec.name.length}="
          puts
          
          puts "Levels:"
          if spec.levels.empty?
            puts "\t(none)"
          else
            spec.levels.sort.each{|lvl| puts "\t- #{lvl}"}
          end
          puts

          puts "Music:"
          if spec.music.empty?
            puts "\t(none)"
          else
            spec.music.sort.each{|m| puts "\t- #{m}"}
          end
          puts

          puts "Graphics:"
          if spec.graphics.empty?
            puts "\t(none)"
          else
            spec.graphics.sort.each{|g| puts "\t- #{g}"}
          end
          puts

          puts "Worlds:"
          if spec.worlds.empty?
            puts "\t(none)"
          else
            spec.worlds.sort.each{|w| puts "\t- #{w}"}
          end
        else
          printf("%-38s | %-38s\n", "Package", "Last updated")
          print("-" * 39, "+", "-" * 40, "\n")
          @cui.local_repository.package_specs.sort_by{|spec| spec.name}.each do |spec|
            #The "last update" of a package in the *local* repository is it’s installation time.
            printf("%-38s | %-38s\n", spec.name, spec.last_update.localtime.strftime("%d-%m-%Y %H:%M"))
          end
        end
      end
      
    end
    
  end
  
end
# vim:set ts=8 sts=2 sw=2 et: #
