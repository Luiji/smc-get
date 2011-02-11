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
    
    class Command
      
      def self.help
        ""
      end
      
      def initialize(args)
        parse(args)
      end
      
      def parse(args)
        raise(NotImplementedError, "#{__method__} has to be overriden in a subclass!")
      end
      
      def execute
        raise(NotImplementedError, "#{__method__} has to be overriden in a subclass!")
      end
      
    end
    
  end
  
end
