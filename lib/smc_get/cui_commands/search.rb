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
    
    class SearchCommand < Command
      
      def self.help
        <<HELP
USAGE: #$0 search [-a][-d][-D][-l][-L][-p][-t] QUERY

Searches the local or remote repository for packages. QUERY is assumed
to be a regular expression.

OPTIONS:
  -a\t--authors\tSearch the author list.
  -d\t--description\tSearch the package descriptions.
  -D\t--difficulty\tSearch the 'difficulty' fields.
  -l\t--only-local\tOnly search local packages. Default is to search remotely.
  -L\t--levels\tSearch for specific level names.
  -p\t--pkgname\tSearch the package files' names.
  -t\t--title\t\tSearch the packages' full titles.
  
  
If you don't specify which fields to use, --pkgname is assumed as it performs
best if used alone.
HELP
      end
      
      def self.summary
        "search\tSearch for a package."
      end
      
      def parse(args)
            CUI.debug("Parsing #{args.count} args for search.")
        raise(InvalidCommandline, "No query given.") if args.empty?
        @search_fields = []
        @only_local = false
        
        while args.count > 1
          arg = args.shift
          case arg
          when "-l", "--only-local" then @only_local = true
          when "-t", "--title" then @search_fields << :title
          when "-d", "--description" then @search_fields << :description
          when "-a", "--authors" then @search_fields << :authors
          when "-D", "--difficulty" then @search_fields << :difficulty
          when "-L", "--levels" then @search_fields << :levels
          when "-p", "--pkgname" then @search_fields << :pkgname
          else
            raise(InvalidCommandline, "Invalid argument #{arg}.")
          end
        end
        #If no search fields were specified, default to :pkgname, because
        #it causes the least network traffic.
        @search_fields << :pkgname if @search_fields.empty?
        #The last command-line arg is the search query
        @query = Regexp.new(args.shift)
      end
      
      def execute(config)
            CUI.debug("Executing search.")
        result = SmcGet::Package.search(@query, @search_fields, @only_local)
        return 2 if result.empty?
        result.each do |pkg|
          #We need to check the only_local option here, because the level
          #version in the repository may be newer than that one installed
          #locally. pkg.installed? wouldn't have telled us that.
          spec = if @only_local
            puts "[LOCAL PACKAGE]"
            pkg.spec
          else
            puts "[REMOTE PACKAGE]"
            pkg.getinfo
          end
          puts "Package title:     #{spec["title"]}"
          puts "Real package name: #{pkg.name}"
          puts "Authors:           #{spec["authors"].join(",")}"
          puts "Difficulty:        #{spec["difficulty"]}"
          puts "Description:"
          puts spec["description"]
          puts
        end
      end
      
    end
    
  end
  
end