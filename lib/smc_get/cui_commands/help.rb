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
    
    class HelpCommand < Command
      
      def self.help
        <<EOF
USAGE: #$0 help [SUBCOMMAND]

Shows help for a special SUBCOMMAND or for smc-get in general.
EOF
      end
      
      def parse(args)
            CUI.debug("Parsing #{args.count} args for help.")
        raise(InvalidCommandline, "Too many arguments.") if args.count > 1
        @command = args.shift #nil if not given
      end
      
      def execute
            CUI.debug("Executing help.")
        if @command
          sym = :"#{@command.capitalize}Command"
          if CUICommands.const_defined?(sym)
            puts CUICommands.const_get(sym).help
          else
            puts "#{@command} is not a valid command."
            return 2
          end
        else
          puts CUI::GENERAL_HELP
        end
      end
      
    end
    
  end
  
end