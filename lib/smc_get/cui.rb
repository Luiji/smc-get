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

require_relative "cui_commands/command"
require_relative "cui_commands/getinfo"
require_relative "cui_commands/help"
require_relative "cui_commands/install"
require_relative "cui_commands/uninstall"
require_relative "cui_commands/search"

module SmcGet
  
  #This is the Console User Interface smc-get exposes. Each command
  #is represented by a class in the CUICommands module. Those classes
  #have three methods: ::help, which should return a summary on how to use
  #the command (NOT print it, that's done by an internal method), #parse,
  #which gets the command-line for the subcommand passed in form of an
  #array you should destructively (i.e. removing the elements) analyse, and
  ##execute which finally executes the command. You are free to print out
  #anything inside that method.
  #
  #Note that inside the #parse method you can set instance variables
  #as you would do for any normal class. You can then grep their values
  #inside the #execute method. Furthermore, if inside #parse you detect
  #an error in the commandline the user provided to you, raise the
  #CUI::InvalidCommandline exception with a meaningful message which will
  #then be presented to the user.
  #
  #The last thing one should do when adding a command, is to modify the
  #help message in the CUI::GENERAL_HELP constant to reflect the existance of
  #a new command.
  #
  #Internally the flow is as follows:
  #1. The user calls CUI#initialize with ARGV.
  #2. That method triggers CUI#parse_commandline and passes ARGV to it.
  #3. #parse_commandline analyses the array it receives and figures out
  #   what command class inside the CUICommands module to instantiate.
  #4. CUICommand::Command.new calls #parse on the instantiated Command
  #   object (this is a subclass of CUICommand::Command). Note that
  #   smc-get has not been set up for now, and calls to Package.new or
  #   the like will fail.
  #5. The user calls CUI#start.
  #6. #start looks into @command and invokes the #execute method on it.
  #7. #start shuts down the interpreter via #exit. If the command execution
  #   method returned an integer value, it is used as the exit status.
  #
  #Have a look at the existing commands to see how it works. Especially
  #+help+ is quite easy to understand, so begin there.
  class CUI
    
    #Class for invalid command-line argument errors.
    class InvalidCommandline < Errors::SmcGetError
    end
    
    #Default location of the configuration file.
    DEFAULT_CONFIG_FILE = CONFIG_DIR + "smc-get.yml"
    
    #The help message displayed to the user when issueing "help".
    GENERAL_HELP =<<EOF
USAGE:
#{$0} [OPTIONS] COMMAND [PARAMETERS...]

DESCRIPTION:
Install and uninstall levels from the Secret Maryo Chronicles contributed level
repository.

COMMANDS:
  install\tinstall a package
  uninstall\tuninstall a package
  getinfo\tget information about a package
  search\tsearch for a package
  help\t\tprint this help message

Use "help COMMAND" to get help on a specific command.

OPTIONS FOR #$0 itself
  -c\t--config-file FILE\tUse FILE as the configuration file.
  -d\t--data-directory DIR\tOverride the data_directory setting from the
  \t\t\t\tconfiguration file.

Report bugs to: luiji@users.sourceforge.net
smc-get home page: <http://www.secretmaryo.org/>
EOF
    
    #Creates a new CUI. Pass in ARGV or a set of command-line arguments
    #you want to and read this class's documentation for knowing what
    #happens then. Call #start on the returned object when you want
    #to execute everything.
    def initialize(argv)
      @config = {}
      parse_commandline(argv)
      load_config_file
      SmcGet.repo_url = @config[:repo_url]
      SmcGet.datadir = @config[:data_directory]
    end
    
    #Starts executing of the CUI. This method never returns, it
    #calls #exit after the command has finished.
    def start
      begin
        ret = @command.execute
        #If numbers are returned they are supposed to be the exit code.
        if ret.kind_of? Integer
          exit ret
        else
          exit
        end
      rescue Errors::SmcGetError => e
        $stderr.puts(e.message) #All SmcGetErrors should have an informative message
        exit 2
      rescue => e #Ouch. Fatal error not intended.
        $stderr.puts("[BUG] #{e.class}")
        $stderr.puts("Please file a bug report at https://github.com/Luiji/smc-get/issues")
        $stderr.puts("and attach this message. Describe what you did so we can")
        $stderr.puts("reproduce it. ")
        raise #Bubble up
      end
    end
    
    private
    
    #Destructively searches through +argv+ (i.e. emptying it) and
    #sets the CLI up. Besides when +help+ is used as the
    #command, nothing is actually executed.
    #
    #This method instantiates one of the various classes in the
    #CUICommands module, making smc-get easily extendable by
    #adding a new class inside that module.
    def parse_commandline(argv)
      #Get options for smc-get itself, rather than it's subcommands.
      #First, define the default behaviour:
      @config_file = DEFAULT_CONFIG_FILE
      #Now, check for updates:
      while !argv.empty? and argv.first.start_with?("-") #All options start with a hyphen, commands cannot
        arg = argv.shift
        case arg
        #-c CONFIG | --config-file CONFIG
        when "-c", "--config-file" then @config_file = Pathname.new(argv.shift)
        when "-d", "--data-directory" then @config[:data_directory] = argv.shift
        else
          $stderr.puts("Invalid option #{arg}.")
          $stderr.puts("Try #$0 help.")
          exit 1
        end
      end
      
      #If nothing is left, the command was left out. Assume 'help'.
      argv << "help" if argv.empty?
      
      #Now parse the subcommand.
      command = argv.shift.to_sym
      sym = :"#{command.capitalize}Command"
      if CUICommands.const_defined?(sym)
        begin
          @command = CUICommands.const_get(sym).new(argv)
        rescue InvalidCommandline => e
          $stderr.puts(e.message)
          $stderr.puts("Try #$0 help.")
          exit 1
        end
      else
        $stderr.puts "Unrecognized command #{command}. Try 'help'."
        exit 1
      end
    end
    
    #Loads the configuration file from the <b>config/</b> directory.
    def load_config_file
      #Check for existance of the configuration file and use the
      #default if it doesn't exist.
      unless @config_file.file?
        $stderr.puts("Configuration file #@config_file not found.")
        $stderr.puts("Falling back to the default configuration file.")
        @config_file = DEFAULT_CONFIG_FILE
      end
      #Load the config file and turn it's keys to symbols
      hsh = Hash[YAML.load_file(@config_file.to_s).map{|k, v| [k.to_sym, v]}]
      @config.merge!(hsh){|key, old_val, new_val| old_val} #Command-line args overwrite those in the config
    end
    
  end
  
end
