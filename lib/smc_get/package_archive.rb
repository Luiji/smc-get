# -*- coding: utf-8 -*-
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
  
  #This class allows for easy compression and decompression of .smcpak
  #files. Please note that during this process no validations are performed,
  #i.e. you have to ensure that the directory you want to compress is in
  #smc package layout and the .smcpak files you want to decompress are
  #really smc packages.
  class PackageArchive

    #Number of bytes to read from a file at a time when it’s being
    #compressed.
    CHUNK_SIZE = 4096
    
    #The location of this archive. A Pathname object.
    attr_reader :path

    class << self
      
      #Compresses all files in +directory+ into a TAR.XZ file with the
      #extension ".smcpak".
      #==Parameters
      #[directory] The directory to compress. This will be the toplevel
      #            directory in the resulting TAR file.
      #[goal_file] Full path to where to place the TAR file.
      #==Return value
      #Returns an object of this class.
      #==Examples
      #  smcpak = PackageArchive.compress("/home/freak/packages/mypackage", "mypackage.smcpak")
      #  puts smcpak.path #=> mypackage.smcpak
      #  
      #  smcpak = PackageArchive.compress("mypackage", "/home/freak/compressed_packages/mypackage.smcpak")
      #  puts smcpak.path #=> /home/freak/compressed_packages/mypackage.smcpak
      def compress(directory, goal_file)
        directory = Pathname.new(directory).expand_path
        tar_file = Pathname.new("#{goal_file}.tar").expand_path
        xz_file = Pathname.new(goal_file).expand_path

        tar_file.open("wb"){|file| compress_dir(directory, file)}
        XZ.compress_file(tar_file, xz_file)
        
        tar_file.delete #We don’t need it anymore
        
        new(xz_file)
      end

      private

      #This method creates a TAR archive inside the given +io+ by
      #recursively packaging all files found in +path+ into it.
      #
      #Note that this method isn’t quite the same as <tt>Minitar.pack</tt>,
      #because there is a big difference in how absolute paths are handled.
      #Consider the following call:
      #
      #  Minitar.pack("/home/freak/foo", file)
      #
      #Inside the TAR you’ll get this:
      #
      #  /
      #    home/
      #      freak/
      #        foo/
      #          1.txt
      #          2.rb
      #
      #Surely not what you wanted, plus a leading / that can be misinterpreted
      #by some archiving programs (e.g. XFCE’s XArchiver). Now compare that
      #to what this method does:
      #
      #  compress_dir("/home/freak/foo", file)
      #
      #Result in the TAR:
      #
      #  foo/
      #    1.txt
      #    2.txt
      #
      #It strippes off the unwanted prefix and just places the actual contents of
      #the last element in +path+ (and it’s subdirectories) inside the TAR
      #archive. For a +path+ relative to the current working directory however
      #this method should behave the same as the usual <tt>Minitar.pack</tt>.
      #
      #Extra bonus: This method is threadsafe, as it doesn’t use +chdir+ to
      #change the directory representation in the TAR file. It uses Minitar’s
      #lowlevel methods instead.
      def compress_dir(path, io)
        raise(ArgumentError, "#{path} is not a directory!") unless path.directory?
        
        Archive::Tar::Minitar::Output.open(io) do |output|
          tar = output.tar #Get the real Writer object
          
          path.find do |entry|
            #This is the path as it will show up inside the tar
            relative_path = entry.relative_path_from(path.parent) #parent b/c first entry must be the toplevel dirname, not "."
            
            #Copy permissions from the original file for the tar’ed file
            stat = entry.stat
            stats = {
              :mode  => stat.mode,
              :mtime => stat.mtime,
              :size  => stat.size,
              :uid   => stat.uid, #Should be nil on Windows
              :gid   => stat.gid  #Should be nil on Windows
            }
            
            if entry.directory?
              tar.mkdir(relative_path.to_s, stats)
            elsif entry.file?
              tar.add_file_simple(relative_path.to_s, stats) do |stream|
                File.open(entry, "rb") do |file|
                  chunk = nil
                  stream.write(chunk) while chunk = file.read(CHUNK_SIZE)
                end
              end
            else
              raise(Errors::CompressionError.new("Unsupported file type for #{entry}!", entry))
            end #if
          end #find
        end #Output.new
      end #compress_dir
    
    end
    
    #Creates a new PackageArchive from an existing .smcpak file.
    #==Parameter
    #[archive] The path to the file.
    #==Return value
    #A new instance of this class.
    #==Example
    #  archive = PackageArchive.new("/home/freak/compressed_packages/mypackage.smcpak")
    def initialize(archive)
      @path = Pathname.new(archive)
    end

    #Decompresses this archive, creating a subdirectory
    #named after the archive without the extension.
    #==Parameters
    #[directory] Where to extract the archive to. Note a subdirectory
    #            will be created below this path.
    #==Return value
    #The path to the subdirectory, a Pathname object.
    #==Example
    #  smcpak = PackageArchive.new("mypackage.smcpak")
    #  puts smcpak.decompress #=> #<Pathname:mypackage>
    def decompress(directory)
      directory = Pathname.new(directory)
      tar_file = directory + @path.basename.to_s.sub(/\.smcpak$/, ".tar")
      dest_dir = directory + tar_file.basename.to_s.sub(/\.tar$/, "")
      
      XZ.decompress_file(@path.to_s, tar_file.to_s)
      Archive::Tar::Minitar.unpack(tar_file.to_s, dest_dir.to_s)
      
      tar_file.delete #We don’t need it anymore
      
      dest_dir
    end

    #Human-readable description of form:
    #  #<SmcGet::PackageArchive <path>>
    def inspect
      "#<#{self.class} #{@path.expand_path}>"
    end
    
  end
  
end
