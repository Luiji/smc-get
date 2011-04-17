#Encoding: UTF-8

module SmcGet
  
  class PackageSpecification
    
    #The keys listed here must be mentioned inside a package spec,
    #otherwise the package is considered broken.
    SPEC_MANDATORY_KEYS = [:title, :authors, :difficulty, :description].freeze
    
    ##
    # :attr_accessor: title
    #The package’s title.
    
    ##
    # :attr_accessor: authors
    #The authors of this package. An array.
    
    ##
    # :attr_accessor: difficulty
    #The difficulty of this package as a string.
    
    ##
    # :attr_accessor: description
    #The description of this package.
    
    ##
    # :attr_accessor: install_message
    #A message to display during installation of this package or nil if
    #no message shall be displayed.
    
    ##
    # :attr_accessor: remove_message
    #A message to display during removing of this package or nil if no
    #message shall be displayed.
    
    ##
    # :attr_accessor: dependecies
    #An array of package names this package depends on, i.e. packages that
    #need to be installed before this one can be installed. The array is
    #empty if no dependecies exist.
    
    ##
    # :attr_accessor: levels
    
    ##
    # :attr_accessor: music
    
    ##
    # :attr_accessor: sounds
    
    ##
    # :attr_accessor: graphics
    
    ##
    # :attr_accessor: worlds
    
    #The name of the package this specification is used in, without any
    #file extension.
    attr_reader :name
    
    ##
    # :attr_reader: compressed_file_name
    #The name of the compressed file this specification should belong to.
    #The same as name, but the extension .smcpak was appended.
    
    ##
    # :attr_reader: spec_file_name
    #The name of the specification file. The same as name, but
    #the extension .yml was appended.
    
    def self.from_file(path)
      info = nil
      begin
        info = YAML.load_file(path.to_s)
      rescue Errno::ENOENT => e
        raise(Errors::InvalidSpecification, "File '#{path}' doesn't exist!")
      rescue => e
        raise(Errors::InvalidSpecification, "Invalid YAML: #{e.message}")
      end
      
      spec = new(File.basename(path).sub(/\.yml$/, ""))
      info.each_pair do |key, value|
        spec.send(:"#{key}=", value)
      end
      
      raise(Errors::InvalidSpecification, spec.validate.first) unless spec.valid?
      
      spec
    end
    
    #Returns the matching package name from the package specification’s name
    #by replacing the .yml extension with .smcpak.
    def self.spec2pkg(spec_file_name) # :nodoc:
      spec_file_name.to_s.sub(/\.yml$/, ".smcpak")
    end
    
    #Returns the matching specification file name from the package’s name
    #by replacing the .smcpak extension with .yml.
    def self.pkg2spec(package_file_name) # :nodoc:
      package_file_name.to_s.sub(/\.smcpak$/, ".yml")
    end
    
    def initialize(pkg_name)
      @info = {:dependencies => [], :levels => [], :music => [], :sounds => [], :graphics => [], :worlds => []}
      @name = pkg_name
    end
    
    #See attribute.
    def compressed_file_name # :nodoc:
      "#@name.smcpak"
    end
    
    #See attribute.
    def spec_file_name # :nodoc:
      "#@name.yml"
    end
    
    [:title, :authors, :difficulty, :description, :install_message, :remove_message, :dependencies, :levels, :music, :sounds, :graphics, :worlds].each do |sym|
      define_method(sym){@info[sym]}
      define_method(:"#{sym}="){|val| @info[sym] = val}
    end
    
    def [](sym)
      if respond_to?(sym)
        send(sym)
      else
        raise(IndexError, "No such specification key: #{sym}!")
      end
    end
    
    def valid?
      validate.empty?
    end
    
    def validate
      errors = []
      
      SPEC_MANDATORY_KEYS.each do |sym|
        errors << "Mandatory key #{sym} is missing!" unless @info.has_key?(sym)
      end
      
      errors
    end
    
    def save(directory)
      raise(Errors::InvalidSpecification, validate.first) unless valid?
      
      path = Pathname.new(directory) + "#{@name}.yml"
      path.open("w"){|f| YAML.dump(@info, f)}
    end
    
  end
  
end
