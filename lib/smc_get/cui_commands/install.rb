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
        
        Dir.mktmpdir("smc-get_install") do |tmpdir|
          @pkg_names.each do |pkg_name|
            if @cui.local_repository.contains?(pkg_name)
              if @reinstall
                puts "Reinstalling #{pkg_name}."
              else
                puts "#{pkg_name} is already installed. Maybe you want --reinstall?."
                next
              end
            end
            puts "Installing #{pkg_name}."
            spec_file = pkg_name + ".yml"
            pkg_file  = pkg_name + ".smcpak"
            
            #Windows doesn't understand ANSI escape sequences, so we have to
            #use the carriage return and reprint the whole line.
            base_str = "\rDownloading %s... (%.2f%%)"
            tries = 0
            begin
              tries += 1
              path_to_spec    = @cui.remote_repository.fetch_spec(spec_file, tmpdir)
              path_to_package = @cui.remote_repository.fetch_package(pkg_file, tmpdir) do |bytes_total, bytes_done|
                percent = ((bytes_done.to_f / bytes_total) * 100)
                print "\r", " " * 80 #Clear everything written before
                printf(base_str, pkg_file, percent)
              end
            rescue OpenURI::HTTPError => e #Thrown even in case of FTP and HTTPS
              if tries >= 3
                $stderr.puts("ERROR: Failed to download #{pkg_name}.")
                $stderr.puts("Continueing with the next package if any.")
                next
              else
                $stderr.puts("ERROR: #{e.message}")
                $stderr.puts("Retrying.")
                retry
              end
            end
            puts #Terminating \n
            puts "Installing #{pkg_file}..."
            pkg = Package.new(path_to_spec, path_to_package)
            @cui.local_repository.install(pkg)
          end #each
        end #mktmpdir
      end #execute
      
    end
    
  end
  
end

# vim:set ts=8 sts=2 sw=2 et: #