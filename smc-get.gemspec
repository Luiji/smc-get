GEMSPEC = Gem::Specification.new do |spec|
  spec.name = "smc-get"
  spec.summary = "Manages Secret Maryo Chronicles levels."
  spec.description =<<DESCRIPTION
smc-get is a apt-get like tool to manage levels that have
been uploaded to the Secret Maryo Chronicles contributed
levels repository. You can install, remove and list the
levels you have installed and search for new ones that
are available online.
DESCRIPTION
  spec.version = File.readlines("VERSION.txt").first.chomp.sub("-", ".")
  spec.author = "Luiji Maryo"
  spec.email = "luiji@users.sourceforge.net"
  spec.platform = Gem::Platform::RUBY
  spec.required_ruby_version = ">= 1.9.2"
  spec.requirements = ["Secret Maryo Chronicles"]
  spec.files = [Dir["bin/*"],
    Dir["lib/**/*.rb"],
    Dir["test/*.rb"],
    Dir["config/*"],
    "COPYING", "README.rdoc", "VERSION.txt"].flatten
  spec.executables = ["smc-get"]
  spec.has_rdoc = true
  spec.extra_rdoc_files = %w[README.rdoc COPYING]
  spec.rdoc_options << "-t" << "smc-get RDocs" << "-m" << "README.rdoc"
  spec.test_files = Dir["test/test_*.rb"]
  spec.homepage = "https://github.com/Luiji/smc-get"
end