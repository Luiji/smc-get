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
  
  #This class allows for easy compression and decompression of .smcpak
  #files. Please note that during this process no validations are performed,
  #i.e. you have to ensure that the directory you want to compress is in
  #smc package layout and the .smcpak files you want to decompress are
  #really smc packages.
  class PackageArchive
    
    #The location of this archive.
    attr_reader :path
    
    #Compresses all files in +directory+ into a TAR.XZ file with the
    #extension ".smcpak".
    #Returns an object of this class.
    #  smcpak = PackageArchive.compress("mypackage")
    #  puts smcpak.path #=> mypackage.smcpak
    def self.compress(directory, goal_file)
      directory = Pathname.new(directory).expand_path
      tar_file = Pathname.new("#{goal_file}.tar").expand_path
      xz_file = Pathname.new(goal_file).expand_path
      
      Dir.chdir(directory.parent) do
        tar_file.open("wb") do |file|
          Archive::Tar::Minitar.pack(directory.relative_path_from(Pathname.new(".").expand_path).to_s, file)
        end
      end
      XZ.compress_file(tar_file, xz_file)
      
      tar_file.delete #We don’t need it anymore
      
      new(xz_file)
    end
    
    #Creates a new PackageArchive from an existing .smcpak file.
    def initialize(archive)
      @path = Pathname.new(archive)
    end
    
    #Decompresses this archive into +directory+, creating a subdirectory
    #named after the archive without the extension, and returns the path
    #to that subdirectory (a Pathname object).
    #  smcpak = PackageArchive.new("mypackage.smcpak")
    #  puts smcpak.decompress #=> #<Pathname:mypackage>
    def decompress(directory)
      directory = Pathname.new(directory)
      tar_file = directory + @path.basename.to_s.sub(/\.smcpak$/, ".tar")
      dest_dir = directory + tar_file.basename.to_s.sub(/\.tar$/, "")
      
      XZ.decompress_file(@path.to_s, tar_file.to_s)
      Archive::Tar::Minitar.unpack(tar_file.to_s, dest_dir.to_s)
      
      tar_file.delete #We don’ŧ need it anymore
      
      dest_dir
    end
    
  end
  
end
