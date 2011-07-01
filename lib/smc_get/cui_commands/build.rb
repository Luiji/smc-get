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
    
    class BuildCommand < Command
      
      def self.help
        <<-EOF
USAGE: #{File.basename($0)} build [DIRECTORY]

If DIRECTORY is given, validates it's structure against the SMC packaging
guidelines and then packages it into a .smcpak file. If DIRECTORY is not
given, enters an interactive process that queries you for the files you
want to include in your SMC package. In both cases you’ll end up with
a SMC package in your current directory.

Files you enter during the interrogative process are looked for in your
user-level SMC directory, i.e. ~/.smc.
        EOF
      end
      
      def self.summary
        "build\t\tBuild SMC packages."
      end
      
      def parse(args)
        CUI.debug("Parsing #{args.count} args for build.")
        raise(InvalidCommandline, "Too many arguments.") if args.count > 1
        @directory = args.shift #nil if not given
      end
      
      def execute(config)
        CUI.debug("Executing build.")
        begin
          if @directory
            Package.create(@directory)
          else #No directory given
            puts(<<-MSG)
Welcome to the smc-get build process! 
Answer the following questions properly and you'll end up with a ready-to-
install package you can either install locally or contribute to the repository
(which would make it installable via 'smc-get install' directly). When a question
asks you to input multiple files, you can end the query with an empty line.
If you like, you can specify multiple files at once by separating them
with a comma. Wildcards in filenames are allowed.

Files you don't specify via an absolute path (i.e. a path beginning with
either / on *nix or <letter>:\\ on Windows) are searched for in your
home directory's .smc directory and your SMC installation.
            MSG
            #All the information will be collected in this hash
            spec = Hash.new{|hsh, key| hsh[key] = []}
            
            #Start the questionaire
            [:levels, :graphics, :music, :sounds, :worlds].each do |sym|
              spec[sym].concat(input_files(sym))
            end

            puts
            puts("Who participated in creating this package?")
            loop do
              print "> "
              str = $stdin.gets.chomp
              
              if str.empty?
                if spec[:authors].empty?
                  $stderr.puts("You have to input at least one author.")
                else
                  break
                end
              else #Something was entered
                spec[:authors].concat(str.split(",").map(&:strip))
              end
            end

            puts
            puts "Enter this package's dependecy packages:"
            loop do
              print "> "
              str = $stdin.gets.chomp
              if str.empty?
                break
              else
                spec[:dependencies].concat(str.split(",").map(&:strip))
              end
            end
            
            loop do
              puts
              print("Enter the difficulty: ")
              break unless (spec[:difficulty] = $stdin.gets.chomp).empty?
            end
            
            puts
            puts("Enter the package's description. A single line containing containg")
            puts("END")
            puts("terminates the query.")
            spec[:description] = ""
            loop do
              print "> "
              str = $stdin.gets #No chomp here, the user may set spaces at the line end intentionally
              if str == "END\n"
                if spec[:description].strip.empty?
                  $stderr.puts("You *have* to input a description!")
                  $stderr.puts("And it must consist of something else than only whitespace!")
                else
                  break
                end
              else
                spec[:description] << str
              end
            end
            
            [:install_message, :remove_message].each{|sym| spec[sym] = input_desc(sym)}
            
            loop do
              puts
              print("Enter the package's full title (it can contain whitespace):")
              spec[:title] = $stdin.gets.chomp
              if spec[:title].strip.empty?
                $stderr.puts "You *have* to specify a title that doesn't consist solely of whitespace!"
              else
                break
              end
            end
            
            pkgname = nil
            loop do
              puts
              print "Enter the package's name (this mustn't contain whitespace):"
              pkgname = $stdin.gets.chomp
              if pkgname.strip.empty?
                $stderr.puts "You *have* to specify a name!"
              elsif pkgname =~ /\s/
                $stderr.puts "The package name mustn't contain whitespace!"
              else
                break
              end
            end

            #Set the last_update spec field to now
            spec[:last_update] = Time.now.utc

            puts
            #This is all. Start building the package.
            Dir.mktmpdir("smc-get-build-package") do |tmpdir|
              puts "Creating package..."
              tmpdir = Pathname.new(tmpdir)
              pkgdir = tmpdir + pkgname
              pkgdir.mkdir
              #Copy all the level, music, etc. files
              [:levels, :music, :sounds, :worlds].each do |sym|
                subdir = pkgdir + sym.to_s
                subdir.mkdir
                spec[sym].each{|file| FileUtils.cp(file, subdir)}
              end
              #The graphics for whatever reason have an own name...
              subdir = pkgdir + "pixmaps"
              subdir.mkdir
              spec[:graphics].each{|file| FileUtils.cp(file, subdir)}
              
              #Turn the file paths in the spec to relative ones and the
              #keys to strings.
              real_spec = {}
              spec.each_pair do |key, value|
                real_spec[key.to_s] = case key
                when :levels, :graphics, :music, :sounds, :worlds then value.map!{|file| File.basename(file)}
                #Further conditions could follow some time
                else
                  value
                end
              end
              
              #Create the spec
              File.open(pkgdir + "#{pkgname}.yml", "w"){|file| YAML.dump(real_spec, file)}
              
              puts "Compressing..."
              pkg = Package.create(pkgdir)
              puts "Copying..."
              FileUtils.cp(pkg.path, "./")
              #compressed_file_name returns only the name of the package file,
              #no path. Expanding it therefore results in the current
              #working directory prepended to it.
              puts "Done. Your package is at #{File.expand_path(pkg.spec.compressed_file_name)}."
            end
              
          end
        rescue Errors::BrokenPackageError => e
          $stderr.puts("Failed to build SMC package:")
          $stderr.puts(e.message)
          if CUI.debug_mode?
            $stderr.puts("Class: #{e.class}")
            $stderr.puts("Message: #{e.message}")
            $stderr.puts("Backtrace:")
            $stderr.puts(e.backtrace.join("\n\t"))
          end
          return 1 #Exit code
        end
      end
      
      private
      
      #Queries the user for a set of file names in an uniform mannor.
      #Pass in the pluralized symbol of the resource you want to query
      #for, e.g. :levels or :graphics. Return value is an array of all
      #found files which may be empty if no files were found.
      def input_files(plural_name)
        result = []
        puts
        puts "Enter the names of the #{plural_name} you want to include:"
        loop do
          print "> "
          str = $stdin.gets.chomp
          
          #Test if the user entered an empty line, i.e. wants to end the
          #query for this question
          if str.empty?
            if result.empty?
              print("No #{plural_name} specified. Is this correct?(y/n) ")
              break if $stdin.gets.chomp.downcase == "y"
            else
              break
            end
          else #User entered something
            str.split(",").each do |file|
              file.strip! #Due to possible whitespace behind the comma
              ary = get_file_paths(plural_name.to_s, file)
              $stderr.puts("Warning: File(s) not found: #{file}. Ignoring.")  if ary.empty?
              result.concat(ary)
            end
          end
        end
        result
      end
      
      #Queries the user for a longer, but optional text that is returned. If
      #the user enters no text beside the END marker, returns nil. Pass in
      #what to tell the user is to be entered.
      def input_desc(sym)
        puts
        puts("Enter the package's #{sym}. A single line containing containg")
        puts("END")
        puts("terminates the query. Enter END immediately if you don't want")
        puts "a #{sym}."
        result = ""
        loop do
          print "> "
          str = $stdin.gets #No chomp here, the user may set spaces at the line end intentionally
          if str == "END\n"
            break
          else
            result << str
          end
        end
        result.empty? ? nil : result
      end
      
      def get_file_paths(plural_name, path)
        #Even on Windows we work with forward slash (Windows supports this,
        #although it’s not well known)
        path = path.gsub("\\", "/")
        ary = []
        #First check if it’s an absolute path
        if RUBY_PLATFORM =~ /mswin|mingw|cygwin/ and path =~ /^[a-z]:/i
          ary.replace(Dir.glob(path)) #Works even without an actual escape char like *
        elsif path.start_with?("/")
          ary.replace(Dir.glob(path))
        else #OK, relative path
          plural_name = "pixmaps" if plural_name == "graphics" #As always...
          
          #The user level directory only contains levels, but for the
          #sake of simplicity I treat it as if sounds etc existed there
          #as well. It doesn’t hurt if not, because that just causes
          #an empty array.
          user_level_dir  = CUI::USER_SMC_DIR + plural_name
          smc_install_dir = @cui.local_repository.path + plural_name
          global_files    = Dir.glob(smc_install_dir.join(path).to_s)
          user_files      = Dir.glob(user_level_dir.join(path).to_s)
          #In case a file with the same name exists in both paths,
          #the user-level file overrides the SMC installation ones’s.
          ary.replace(user_files)
          global_files.each{|path| ary << path unless ary.any?{|p2| File.basename(path) == File.basename(p2)}}
        end
        ary
      end
      
    end
    
  end
  
end
# vim:set ts=8 sts=2 sw=2 et: #
