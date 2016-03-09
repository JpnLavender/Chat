# -*- encoding: utf-8 -*-
# stub: http_router 0.5.4 ruby lib

Gem::Specification.new do |s|
  s.name = "http_router"
  s.version = "0.5.4"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib"]
  s.authors = ["Joshua Hull"]
  s.date = "2011-02-28"
  s.description = "This library allows you to recognize and build URLs in a Rack application. As well it contains an interface for use within Sinatra."
  s.email = "joshbuddy@gmail.com"
  s.extra_rdoc_files = ["README.rdoc"]
  s.files = ["README.rdoc"]
  s.homepage = "http://github.com/joshbuddy/http_router"
  s.rdoc_options = ["--charset=UTF-8"]
  s.rubyforge_project = "http_router"
  s.rubygems_version = "2.4.5.1"
  s.summary = "A kick-ass HTTP router for use in Rack & Sinatra"

  s.installed_by_version = "2.4.5.1" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<rack>, [">= 1.0.0"])
      s.add_runtime_dependency(%q<url_mount>, ["~> 0.2.1"])
      s.add_development_dependency(%q<minitest>, ["~> 2.0.0"])
      s.add_development_dependency(%q<code_stats>, [">= 0"])
      s.add_development_dependency(%q<rake>, [">= 0"])
      s.add_development_dependency(%q<sinatra>, [">= 0"])
      s.add_development_dependency(%q<rbench>, [">= 0"])
      s.add_development_dependency(%q<phocus>, [">= 0"])
      s.add_development_dependency(%q<bundler>, ["~> 1.0.0"])
    else
      s.add_dependency(%q<rack>, [">= 1.0.0"])
      s.add_dependency(%q<url_mount>, ["~> 0.2.1"])
      s.add_dependency(%q<minitest>, ["~> 2.0.0"])
      s.add_dependency(%q<code_stats>, [">= 0"])
      s.add_dependency(%q<rake>, [">= 0"])
      s.add_dependency(%q<sinatra>, [">= 0"])
      s.add_dependency(%q<rbench>, [">= 0"])
      s.add_dependency(%q<phocus>, [">= 0"])
      s.add_dependency(%q<bundler>, ["~> 1.0.0"])
    end
  else
    s.add_dependency(%q<rack>, [">= 1.0.0"])
    s.add_dependency(%q<url_mount>, ["~> 0.2.1"])
    s.add_dependency(%q<minitest>, ["~> 2.0.0"])
    s.add_dependency(%q<code_stats>, [">= 0"])
    s.add_dependency(%q<rake>, [">= 0"])
    s.add_dependency(%q<sinatra>, [">= 0"])
    s.add_dependency(%q<rbench>, [">= 0"])
    s.add_dependency(%q<phocus>, [">= 0"])
    s.add_dependency(%q<bundler>, ["~> 1.0.0"])
  end
end
