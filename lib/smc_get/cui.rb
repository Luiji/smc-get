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

#Load all the files in the cui_commands directory.
require_relative "cui_commands/command"
Dir[File.join(File.expand_path(File.dirname(__FILE__)), "cui_commands", "*.rb")].each do |filename|
  require_relative "cui_commands/#{File.basename(filename)}"
end

module SmcGet
  
  #This is the Console User Interface smc-get exposes. Each command
  #is represented by a class in the CUICommands module. Those classes
  #have three methods: ::help, which should return a summary on how to use
  #the command (NOT print it, that's done by an internal method), #parse,
  #which gets the command-line for the subcommand passed in form of an
  #array you should destructively (i.e. removing the elements) analyse,
  #and #execute which finally executes the command. You are free to print out
  #anything inside that method.
  #
  #Note that inside the #parse method you can set instance variables
  #as you would do for any normal class. You can then grep their values
  #inside the #execute method. Furthermore, if inside #parse you detect
  #an error in the commandline the user provided to you, raise the
  #CUI::InvalidCommandline exception with a meaningful message which will
  #then be presented to the user.
  #
  #The last things one should do when adding a command, is to provide
  #a ::help class method that returns help on the usage of the command
  #(it will be called when the user issues <tt>smc-get help YOURCOMMAND</tt>
  #and it's return value will be shown to the user) and to provide
  #a ::summary class method whose return value is integrated in the
  #output of <tt>smc-get help</tt> under the COMMANDS section.
  #
  #In every method you add, you can make use of the CUI.debug method. If you
  #hand it a string, it will be printed only if running in debug mode, and
  #if you hand it any other object, it's +inspect+ value will be printed--if
  #running in debug mode. See the SmcGet::CUICommands::Command class's
  #documentation for more information on the hook methods.
  #
  #Internally the flow is as follows:
  #1. The user calls CUI#initialize with ARGV.
  #2. That method triggers CUI#parse_commandline and passes ARGV to it.
  #3. #parse_commandline analyses the array it receives and figures out
  #   what command class inside the CUICommands module to instantiate.
  #4. CUICommand::Command.new calls #parse on the instantiated Command
  #   object (this is a subclass of CUICommand::Command). Note that
  #   smc-get has not been set up for now, and calls to Repository#install or
  #   the like will fail.
  #5. The user calls CUI#start.
  #6. #start looks into @command and invokes the #execute method on it.
  #7. #start shuts down the interpreter via #exit. If the command execution
  #   method returned an integer value, it is used as the exit status.
  #
  #Have a look at the existing commands to see how it works. Especially
  #+help+ is quite easy to understand, so begin there.
  class CUI
    
    #Default location of the configuration file.
    DEFAULT_CONFIG_FILE = CONFIG_DIR + "smc-get.yml"
    #The user’s personal directory.
    USER_DIR = Pathname.new(ENV["HOME"])
    #The user-level smc-get configuration file.
    USER_CONFIG_FILE = USER_DIR + ".smc-get-conf.yml"
    #A user’s personal SMC data directory.
    USER_SMC_DIR = USER_DIR + ".smc"
    #The help message displayed to the user when issueing "help".
    GENERAL_HELP =<<EOF
USAGE:
#{File.basename($0)} [OPTIONS] COMMAND [PARAMETERS...]

DESCRIPTION:
Install and uninstall levels from the Secret Maryo Chronicles contributed level
repository.

COMMANDS:
#{str = ''
CUICommands.constants.sort.each do |c|
  next if c == :Command or c == :InvalidCommandline
  str << '  ' << CUICommands.const_get(c).summary << "\n"
  end
str}

Use "help COMMAND" to get help on a specific command. "help" without an
argument displays this message.

OPTIONS FOR #{File.basename($0).upcase} ITSELF
  -c\t--config-file FILE\tUse FILE as the configuration file.
  -d\t--data-directory DIR\tSet the directory where to save packages into.
  -D\t--debug\t\t\tEnter debug mode. A normal user shouldn't use this.
  -r\t--repo-url URL\t\tSet the URL of the remote package repository.

CONFIGURATION FILES
You can use three kinds of configuration files with #{File.basename($0)}. They are,
in the order in which they are evaluated:

1. Global configuration file #{DEFAULT_CONFIG_FILE}.
2. If existant, user-level configuration file #{USER_CONFIG_FILE}.
3. If existant, configuration file given on the commandline via the -c option.

Configuration files loaded later overwrite values set in previously loaded
configuration files, i.e. values set in the configuration file provided via
the commandline override those in the global and user-level configuration
file, and those in the user-level configuration file override those in the
global configuration file, etc.
There is a 4th way to set options for #{File.basename($0)}:

4. Options given via the commandline

They override anything set in the configuration files, so specifying
'-d /opt/smc' on the commandline would override any 'data_directory'
setting in any of the configuration files.

BUG REPORTING

Report bugs to: luiji@users.sourceforge.net
smc-get home page: <http://www.secretmaryo.org/>
EOF
    
    attr_reader :config
    attr_reader :remote_repository
    attr_reader :local_repository
    
    #Writes <tt>obj.inspect</tt> to $stdout if the CUI is running in debug
    #mode. If +obj+ is a string, it is simply written out.
    def self.debug(obj)
      if @DEBUG_MODE
        if obj.kind_of? String
          puts obj
        else
          puts(obj.inspect)
        end
      end
    end
    
    @DEBUG_MODE = false
    
    #Returns wheather or not we're running in debug mode.
    def self.debug_mode?
      @DEBUG_MODE
    end
    
    #Set to +true+ to enable debug mode.
    def self.debug_mode=(val)
      @DEBUG_MODE = val
    end
    
    #Creates a new CUI. Pass in ARGV or a set of command-line arguments
    #you want to and read this class's documentation for knowing what
    #happens then. Call #start on the returned object when you want
    #to execute everything.
    def initialize(argv)
      @config = {}
      parse_commandline(argv)
      load_config_file
      SmcGet.setup
      begin
        @local_repository = SmcGet::LocalRepository.new(@config[:data_directory])
        @remote_repository = SmcGet::RemoteRepository.new(@config[:repo_url])
      rescue Errors::InvalidRepository => e
        $stderr.puts("WARNING: Couldn't connect to this repository:")
        $stderr.puts(e.repository_uri)
        $stderr.puts("Reason: #{e.message}")
      end
    end
    
    #Starts executing of the CUI. This method never returns, it
    #calls #exit after the command has finished.
    def start
      begin
        ret = @command.execute(@config)
        #If numbers are returned they are supposed to be the exit code.
        if ret.kind_of? Integer
          exit ret
        else
          exit
        end
      rescue Errno::EACCES, Errors::SmcGetError => e
        $stderr.puts("ERROR: #{e.message}") #All SmcGetErrors should have an informative message (and the EACCES one too)
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
      #Get options for smc-get itself, rather than it's subcommands. Values set
      #here override anything set in any configuration file; but since the
      #keys are turned to symbols in #load_config_file, we have to use
      #strings as keys here (otherwise merging with the config files'
      #settings would fail).
      @cmd_config = nil
      while !argv.empty? and argv.first.start_with?("-") #All options start with a hyphen, commands cannot
        arg = argv.shift
        case arg
        when "-c", "--config-file" then @cmd_config = Pathname.new(argv.shift)
        when "-d", "--data-directory" then @config["data_directory"] = argv.shift
        when "-D", "--debug" then CUI.debug_mode = true
        when "-r", "--repo-url" then @config["repo_url"] = argv.shift
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
      CUI.debug("Found subcommand #{command}.")
      sym = :"#{command.capitalize}Command"
      if CUICommands.const_defined?(sym)
        begin
          @command = CUICommands.const_get(sym).new(self, argv)
        rescue CUICommands::InvalidCommandline => e
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
      #First, load the global configuration file.
      CUI.debug("Loading global config #{DEFAULT_CONFIG_FILE}.")
      hsh = YAML.load_file(DEFAULT_CONFIG_FILE)
      CUI.debug(hsh)
      
      #Second, load the user config which overrides values set in
      #the global config.
      CUI.debug("Loading user-level config #{USER_CONFIG_FILE}.")
      if USER_CONFIG_FILE.file?
        hsh.merge!(YAML.load_file(user_config_file.to_s))
      else
        CUI.debug("Not found.")
      end
      CUI.debug(hsh)
      
      #Third, load the config file from the commandline, if any. This overrides
      #values set in the user and global config.
      if @cmd_config
        CUI.debug("Loading -c option config #{@cmd_config}.")
        if @cmd_config.file?
          hsh.merge!(YAML.load_file(@cmd_config.to_s))
        else
          $stderr.puts("Configuration file #{@cmd_config} not found.")
        end
        CUI.debug(hsh)
      end
      
      #Fourth, check for values on the commandline. They override anything
      #set previously. They are set directly in @config, so we simply have
      #to retain the old values in it.
      CUI.debug("Loading commandline options.")
      @config.merge!(hsh){|key, old_val, new_val| old_val}
          CUI.debug(@config)
      
      #Fifth, turn all keys into symbols, because that's more Ruby-like.
      CUI.debug("Converting to symbols.")
      @config = Hash[@config.map{|k, v| [k.to_sym, v]}]
      CUI.debug(@config)
    end
    
  end
  
end

# vim:set ts=8 sts=2 sw=2 et: #