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
    
    #Class for invalid command-line argument errors.
    class InvalidCommandline < Errors::SmcGetError
    end
    
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
      #tabs to make it display correctly; make sure to check the result by
      #issueing <tt>smc-get help</tt>.
      def self.summary
        ""
      end
      
      #Creates a new instance of this command. Do not override this, or
      #call at least +super+.
      def initialize(cui, args)
        @cui = cui
        parse(args)
      end
      
      #This method gets all commandline options relevant for this subcommand
      #passed in the +args+ array. You should parse them destructively, i.e.
      #after you finished parsing, +args+ should be an empty array.
      #Set instance variables to save data.
      #
      #Note that SmcGet is not set up when this method is called, so you
      #cannot do things like <tt>Package.new</tt>.
      def parse(args)
        raise(NotImplementedError, "#{__method__} has to be overriden in a subclass!")
      end
      
      #Execute the command. You can use the instance variables set in #parse.
      #The method gets passed the parsed contents of smc-get's configuration
      #files and commandline parameters; you can use this to make your command
      #configurable via the configuration file, but make sure that
      #1. The keys you use for your configuration don't already exist,
      #2. options specified on the commandline take precedence over values
      #   set in the configuration file and
      #3. you <b>do not alter</b> the hash.
      def execute(config)
        raise(NotImplementedError, "#{__method__} has to be overriden in a subclass!")
      end

      private

      #Downloads the package identified by +pkgname+ and displays the progress to the
      #user. Example:
      #  download_package("cool_world")
      #downloads the package "cool_world.smcpak". You mustn’t specify the file
      #extension <tt>.smcpak</tt>.
      def download_package(pkgname)
        pkg_file = "#{pkgname}.smcpak"
        #Windows doesn't understand ANSI escape sequences, so we have to
        #use the carriage return and reprint the whole line.
        base_str = "\rDownloading %s... (%.2f%%)"
        tries = 0
        begin
          tries += 1
          path_to_package = @cui.remote_repository.fetch_package(pkg_file, SmcGet.temp_dir) do |bytes_total, bytes_done|
            percent = ((bytes_done.to_f / bytes_total) * 100)
            print "\r", " " * 80 #Clear everything written before
            printf(base_str, pkg_file, percent)
          end
        rescue OpenURI::HTTPError => e #Thrown even in case of FTP and HTTPS
          if tries >= 3
            raise #Bubble up
          else
            $stderr.puts("ERROR: #{e.message}")
            $stderr.puts("Retrying.")
            retry
          end
        end
        puts #Terminating \n
        return path_to_package
      end
      
    end
    
  end
  
end

# vim:set ts=8 sts=2 sw=2 et: #
