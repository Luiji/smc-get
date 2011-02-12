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
    
    #This is the superclass of all CUI commands. To make your own command,
    #subclass it an overwrite ::help, ::summary, #parse and #execute.
    class Command
      
      #The string returned from this method will be displayed to the
      #user if he issues <tt>smc-get help YOURCOMMAND</tt>.
      def self.help
        "(nothing known)"
      end
      
      #One-line summary of the command that shows up in the COMMANDS
      #section of <tt>smc-get help</tt>. Should not be longer than 78
      #characters due to automatic indentation. You may have to insert
      #tabs to make it displaycorrectly; make sure to check the result by
      #issueing <tt>smc-get help</tt>.
      def self.summary
        ""
      end
      
      #Creates a new instance of this command. Do not override this, or
      #call at least +super+.
      def initialize(args)
        parse(args)
      end
      
      #This method gets all commandline options relevant for this subcommand
      #passed in the +args+ array. You should parse them destructively, i.e.
      #after you finished parsing, +args+ should be an empty array.
      #Set instance variables to save data.
      #
      #Note that SmcGet is not set up when this method is called, so you
      #cannot to things like <tt>Package.new</tt>.
      def parse(args)
        raise(NotImplementedError, "#{__method__} has to be overriden in a subclass!")
      end
      
      #Execute the command. You can use the instance variables set in #parse.
      def execute
        raise(NotImplementedError, "#{__method__} has to be overriden in a subclass!")
      end
      
    end
    
  end
  
end
