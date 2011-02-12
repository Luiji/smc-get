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
    
    class GetinfoCommand < Command
      
      def self.help
        <<HELP
USAGE: #$0 getinfo [-r] PACKAGE

Retrieves information about PACKAGE.

OPTIONS:
\r-r\t--remote\tForces getinfo to do a remote lookup.

The default behaviour is to do a local lookup if the
package is already installed.
HELP
      end
      
      def parse(args)
        raise(InvalidCommandline, "No package given.") if args.empty?
        @force_remote = false
        
        while args.count > 1
          arg = args.shift
          case arg
          when "-r", "--remote" then @force_remote = true
          else
            raise(InvalidCommandline, "Invalid argument #{arg}.")
          end
        end
        #The last command-line arg is the package
        @pkg_name = args.shift
      end
      
      def execute
        pkg = Package.new(@pkg_name)
        #Get the information
        info = if pkg.installed? and !@force_remote
          puts "[LOCAL PACKAGE]"
          pkg.spec
        else
          puts "[REMOTE PACKAGE]"
          pkg.getinfo
        end
        #Now output the information
        puts "Title: #{info['title']}"
        if info['authors'].count == 1
          puts "Author: #{info['authors'][0]}"
        else
          puts 'Authors:'
          info['authors'].each do |author|
            puts "  - #{author}"
          end
        end
        puts "Difficulty: #{info['difficulty']}"
        puts "Description: #{info['description']}"
      end
      
    end
    
  end
  
end