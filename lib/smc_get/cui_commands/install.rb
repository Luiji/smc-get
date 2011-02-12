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
USAGE: #$0 install [-r] PACKAGE

Installs a package.

OPTIONS:
  -r\t--reinstall\tForces a reinstallation of the package.
HELP
      end
      
      def self.summary
        "install\tInstall a package."
      end
      
      def parse(args)
            CUI.debug("Parsing #{args.count} args for install.")
        raise(InvalidCommandline, "No package given.") if args.empty?
        @reinstall = false
        
        while args.count > 1
          arg = args.shift
          case arg
          when "--reinstall", "-r" then @reinstall = true
          else
            raise(InvalidCommandline, "Invalid argument #{arg}.")
          end
        end
        #The last command-line arg is the package
        @pkg_name = args.shift
      end
      
      def execute(config)
            CUI.debug("Executing install.")
        pkg = Package.new(@pkg_name)
        if pkg.installed?
          if @reinstall
            puts "Reinstalling #{pkg}."
          else
            puts "Already installed. Nothing to do, maybe you want --reinstall?."
            return
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
