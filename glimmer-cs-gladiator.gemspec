# Generated by jeweler
# DO NOT EDIT THIS FILE DIRECTLY
# Instead, edit Jeweler::Tasks in Rakefile, and run 'rake gemspec'
# -*- encoding: utf-8 -*-
# stub: glimmer-cs-gladiator 0.4.1 ruby lib

Gem::Specification.new do |s|
  s.name = "glimmer-cs-gladiator".freeze
  s.version = "0.4.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Andy Maleh".freeze]
  s.date = "2020-10-24"
  s.description = "Gladiator (short for Glimmer Editor) is a Glimmer sample project under on-going development. It is not intended to be a full-fledged editor by any means, yet mostly a fun educational exercise in using Glimmer to build a text editor. Gladiator is also a personal tool for shaping an editor exactly the way I like. I leave building truly professional text editors to software tooling experts who would hopefully use Glimmer one day.".freeze
  s.email = "andy.am@gmail.com".freeze
  s.executables = ["gladiator".freeze]
  s.extra_rdoc_files = [
    "LICENSE.txt",
    "README.md"
  ]
  s.files = [
    "LICENSE.txt",
    "README.md",
    "VERSION",
    "bin/gladiator",
    "bin/gladiator_runner.rb",
    "lib/glimmer-cs-gladiator.rb",
    "lib/models/glimmer/gladiator/command.rb",
    "lib/models/glimmer/gladiator/dir.rb",
    "lib/models/glimmer/gladiator/file.rb",
    "lib/views/glimmer/gladiator.rb",
    "lib/views/glimmer/gladiator/text_editor.rb"
  ]
  s.homepage = "http://github.com/AndyObtiva/glimmer-cs-gladiator".freeze
  s.licenses = ["MIT".freeze]
  s.rubygems_version = "3.1.4".freeze
  s.summary = "Gladiator (Glimmer Editor) - Glimmer Custom Shell".freeze

  if s.respond_to? :specification_version then
    s.specification_version = 4
  end

  if s.respond_to? :add_runtime_dependency then
    s.add_runtime_dependency(%q<glimmer-dsl-swt>.freeze, [">= 4.17.5.0", "< 5.0.0.0"])
    s.add_runtime_dependency(%q<filewatcher>.freeze, ["~> 1.1.1"])
    s.add_runtime_dependency(%q<clipboard>.freeze, ["~> 1.3.4"])
    s.add_development_dependency(%q<rspec>.freeze, ["~> 3.5.0"])
    s.add_development_dependency(%q<jeweler>.freeze, ["= 2.3.9"])
    s.add_development_dependency(%q<simplecov>.freeze, [">= 0"])
  else
    s.add_dependency(%q<glimmer-dsl-swt>.freeze, [">= 4.17.5.0", "< 5.0.0.0"])
    s.add_dependency(%q<filewatcher>.freeze, ["~> 1.1.1"])
    s.add_dependency(%q<clipboard>.freeze, ["~> 1.3.4"])
    s.add_dependency(%q<rspec>.freeze, ["~> 3.5.0"])
    s.add_dependency(%q<jeweler>.freeze, ["= 2.3.9"])
    s.add_dependency(%q<simplecov>.freeze, [">= 0"])
  end
end

