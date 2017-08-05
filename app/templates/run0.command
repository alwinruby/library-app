#!/bin/bash
exec ruby -x "$0"

#!ruby

#
# run.rb
# ======
#
# This is the code runner script for use with the book:
#
#   Programming for Beginners
#   Learn to Code by Making Little Games
#   by Tom Dalling
#
#   http://www.programmingforbeginnersbook.com/
#
# It is designed to allow programming students to easily run
# their Ruby code by double-clicking a file. When run, this script
# looks for a file named either `main.rb` or `game.rb` within the
# same directory, and runs the code therein. Some features include:
#
#  - It works on Windows and OS X
#  - It displays whether the code crashed or finished successfully
#  - It prevents the shell from disappearing immediately after exit,
#    allowing the user to read the output
#  - If a Gemfile exists in the directory, it will `gem install bundler` and
#    `bundle install`, before using `bundle exec` to run the code.
#

at_exit do
  puts $! if $!
  pause_and_exit(1)
end

module Windows
  extend self

  def clear_terminal
    system('cls')
  end

  def null_file
    'NUL'
  end
end

module Posix
  extend self

  def clear_terminal
    system('clear')
  end

  def null_file
    '/dev/null'
  end
end

DEBUG = ARGV.include?('--debug')
DISPLAY_WIDTH = 70 # characters
PLATFORM = (RbConfig::CONFIG['host_os'] =~ /mswin|mingw|cygwin/) ? Windows : Posix
RUBY_BIN_PATH = RbConfig.ruby
GEM_BIN_PATH = File.join(RbConfig::CONFIG['bindir'], 'gem')
ENTRY_POINT_FILE_NAMES = [
  'main.rb',
  'game.rb',
]

def sh(*args)
  opts = {
    silent: false,
  }
  opts.merge!(args.pop) if args.last.is_a?(Hash)

  popts = if opts[:silent]
    { out: PLATFORM.null_file, err: PLATFORM.null_file }
  else
    { in: :in, out: :out, err: :err }
  end

  pid = Process.spawn(*args, popts)
  _, status = Process.waitpid2(pid)
  return (status.exitstatus == 0)
end

def assert_sh(*args)
  puts "Running: #{args.inspect}"
  pause_and_exit(1) unless sh(*args)
end

def banner(padding, text)
  line = " ".rjust(11, padding) + text.strip + " "
  puts line.ljust(DISPLAY_WIDTH, padding)
end

def pause_and_exit(status)
  puts
  puts "Press enter to exit..."
  gets
  exit!(status)
end

def gemfile
  ['Gemfile', 'GemFile'].find { |f| File.exist?(f) }
end

def clear_terminal
  PLATFORM.clear_terminal unless DEBUG
end

banner '?', 'Debug mode activated' if DEBUG

Dir.chdir(File.dirname(__FILE__))
puts "PWD: #{Dir.pwd}" if DEBUG
clear_terminal
main_file = ENTRY_POINT_FILE_NAMES.find{ |f| File.exist?(f) }
has_gemfile = !!gemfile
bundle_bin_path = begin
  Gem.bin_path('bundler', 'bundle')
rescue Exception => e
  nil
end

if has_gemfile
  # check for bundler
  unless bundle_bin_path
    puts 'Bundler is not installed. Installing now...'
    assert_sh(GEM_BIN_PATH, 'install', 'bundler')
    bundle_bin_path = %x{ #{RUBY_BIN_PATH} -e "puts Gem.bin_path('bundler', 'bundle')" }.strip
    raise "Failed to install bundler" unless File.exist?(bundle_bin_path)
  end

  # check that everything in gemfile is installed
  unless sh(RUBY_BIN_PATH, bundle_bin_path, 'check', silent: true)
    puts 'Installing gems from Gemfile...'
    assert_sh(RUBY_BIN_PATH, bundle_bin_path, 'install')
  end
end

if main_file.nil?
  puts "Error: Can't find any ruby files to run."
  puts "Make sure a file exists with one of these names:"
  ENTRY_POINT_FILE_NAMES.each do |f|
    puts "  #{f}"
  end
  pause_and_exit(1)
end

clear_terminal
banner '>', "Running: #{main_file}"
cmd = (has_gemfile ? [RUBY_BIN_PATH, bundle_bin_path, 'exec'] : []) + [RUBY_BIN_PATH, main_file]
succeeded = sh(*cmd)
# also consider `require_relative main_file`, but might need to restart after bundle install
if succeeded
  banner '<', 'Finished successfully'
else
  banner '!', 'Ruby has crashed'
end

pause_and_exit(succeeded ? 0 : 1)
