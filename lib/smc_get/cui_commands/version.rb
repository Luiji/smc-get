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
    
    class VersionCommand < Command
      
      def self.help
        <<EOF
USAGE: #{File.basename($0)} version

Shows the version of #{File.basename($0)} and the copyright statement.
EOF
      end
      
      def self.summary
        "version\tShows smc-get's version and copyright."
      end
      
      def parse(args)
        raise(InvalidCommandline, "Too many arguments.") unless args.empty?
      end
      
      def execute(config)
        puts "This is #{File.basename($0)}, version #{VERSION}."
        puts
        puts "#{File.basename($0)}  Copyright (C) 2010-2011  Luiji Maryo"
        puts "#{File.basename($0)}  Copyright (C) 2011  Marvin Gülker"
        puts "This program comes with ABSOLUTELY NO WARRANTY."
        puts "This is free software, and you are welcome to redistribute it"
        puts "under certain conditions; see the COPYING file for information."
      end
      
    end
    
  end
  
end