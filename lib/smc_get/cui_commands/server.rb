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

class SmcGet::CUICommands::ServerCommand < SmcGet::CUICommands::Command

  def self.help
    <<-EOF
USAGE: #{File.basename($0)} server [-p PORT] [DIRECTORY]

Starts a simple static file server you can use to connect to
with another instance of #{File.basename($0)}. Note that it uses
Ruby's WEBrick, which is known to not be suitable for production
environments, so don't use this command for anything else than
serving small more-or-less private SMC repositories. Have a look
at robust servers like apache or nginx for making it available to
the public.

If DIRECTORY is given, uses that directory for the server root
directory. Otherwise, uses the current working directory.

OPTIONS
-p PORT\t--port PORT\tListen on this port instead of the default 3000.
    EOF
  end

  def self.summary
    "server\tStart a repository server."
  end

  def parse(args)
    SmcGet::CUI.debug("Parsing #{args.count} args for server.")
    
    until args.empty?
      arg = args.shift
      case arg
      when "--port", "-p" then @port = args.shift || raise(InvalidCommandline, "No port given.")
      else
        @directory = Pathname.new(arg).expand_path
      end
    end
    
    @directory ||= Pathname.pwd
    @port      ||= 3000
  end

  def execute(config)
    server  = WEBrick::HTTPServer.new(Port: @port)
    server[:Logger].info("Serving directory #@directory.")
    server.mount("/", WEBrick::HTTPServlet::FileHandler, @directory)
    
    Signal.trap("SIGINT") do
      server[:Logger].info("Cought SIGINT, stopping...")
      server.stop
    end
    
    server.start
  end

end
