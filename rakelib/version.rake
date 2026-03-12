# frozen_string_literal: true

VERSION_FILE = 'lib/knox_train/version.rb'
FORMULA_FILE = 'tap/Formula/knox_train.rb'

# Always reads from disk so it's accurate after write_version runs
def current_version
  File.read(VERSION_FILE).match(/VERSION = ['"]([^'"]+)['"]/)[1]
end

def bump(part)
  maj, min, pat = current_version.split('.').map(&:to_i)
  case part
  when :major then "#{maj + 1}.0.0"
  when :minor then "#{maj}.#{min + 1}.0"
  when :patch then "#{maj}.#{min}.#{pat + 1}"
  end
end

def write_version(ver)
  File.write(VERSION_FILE, "module KnoxTrain\n  VERSION = \"#{ver}\"\nend\n")
  content = File.read(FORMULA_FILE)
  File.write(FORMULA_FILE, content.sub(/  version ".*"/, "  version \"#{ver}\""))
  puts "Version updated to #{ver}"
end

desc 'Print current version'
task :version do
  puts current_version
end

namespace :version do
  desc 'Set an explicit version: rake version:set[2.1.0]'
  task :set, [:v] do |_, args|
    raise 'Usage: rake version:set[X.Y.Z]' unless args[:v] =~ /\A\d+\.\d+\.\d+\z/

    write_version(args[:v])
  end

  desc 'Bump major version (e.g. 2.0.0 → 3.0.0)'
  task :major do
    write_version(bump(:major))
  end

  desc 'Bump minor version (e.g. 2.0.0 → 2.1.0)'
  task :minor do
    write_version(bump(:minor))
  end

  desc 'Bump patch version (e.g. 2.0.0 → 2.0.1)'
  task :patch do
    write_version(bump(:patch))
  end
end

namespace :release do
  desc 'Bump patch version, commit, and redeploy via Homebrew'
  task :patch do
    write_version(bump(:patch))
    Rake::Task['release:deploy'].invoke
  end

  desc 'Bump minor version, commit, and redeploy via Homebrew'
  task :minor do
    write_version(bump(:minor))
    Rake::Task['release:deploy'].invoke
  end

  desc 'Bump major version, commit, and redeploy via Homebrew'
  task :major do
    write_version(bump(:major))
    Rake::Task['release:deploy'].invoke
  end

  desc 'Set explicit version, commit, and redeploy: rake release:set[2.1.0]'
  task :set, [:v] do |_, args|
    raise 'Usage: rake release:set[X.Y.Z]' unless args[:v] =~ /\A\d+\.\d+\.\d+\z/

    write_version(args[:v])
    Rake::Task['release:deploy'].invoke
  end

  # Internal: commit version files + redeploy Homebrew
  task :deploy do
    v = current_version
    sh "git add #{VERSION_FILE}"
    sh "git commit -m 'Release v#{v}'"
    sh "git -C tap add Formula/knox_train.rb && git -C tap commit -m 'Release v#{v}'"
    Rake::Task['brew:reinstall'].invoke
  end
end
