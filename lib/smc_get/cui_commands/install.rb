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
          pkg = Package.new(pkg_name)
          if pkg.installed?
            if @reinstall
              puts "Reinstalling #{pkg}."
            else
              puts "#{pkg} is already installed. Maybe you want --reinstall?."
              next
            end
          end
          puts "Installing #{pkg}."
          #Windows doesn't understand ANSI escape sequences, so we have to
          #use the carriage return and reprint the whole line.
          base_str = "\rDownloading %s... (%.2f%%)"
          pkg.install(config[:max_tries]) do |filename, percent_filename, retrying|
            if retrying
              puts "#{retrying.message} Retrying."
            else
              print "\r", " " * 80 #Clear everything written before
              printf(base_str, filename, percent_filename)
            end
          end
          puts
        end
      end
      
    end
    
  end
  
end

# vim:set ts=8 sts=2 sw=2 et: #