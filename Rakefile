# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rake/testtask'

Rake::TestTask.new(:test) do |t|
  t.libs << 'test'
  t.libs << 'lib'
  t.test_files = FileList['test/**/*_test.rb']
end

desc 'Remove rbenv gem install and stale .gem artifacts (run once before brew:install)'
task :purge do
  sh 'gem uninstall knox_train --executables --ignore-dependencies --force 2>/dev/null || true'
  sh 'rbenv rehash'
  sh 'rm -f knox_train-*.gem'
  puts 'Purge complete. Verify with: which knox  (should be empty)'
  puts 'Then run: rake brew:install'
end

task default: :test
