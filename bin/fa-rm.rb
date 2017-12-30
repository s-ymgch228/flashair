#!/usr/bin/ruby
require 'optparse'


REPO_PATH = File.dirname(__FILE__)
require "#{REPO_PATH}/../lib/flashair.rb"

def find_file(dir, name)


  rv
end

def do_remove(ip, target, opt)
  target_dir = File.dirname(target)
  target_file = File.basename(target)

  # search file or directory
  fa_files = Flashair.do_ls(ip, target_dir)
  return false if fa_files.nil?

  puts "fa_files: #{fa_files}" if opt[:debug]

  file = nil
  fa_files.each do |f|
    if f.name == target_file
      file = f
      break;
    end
  end

  if file.nil?
    puts "no such a file or directory : #{target}"
    return true
  end

  if file.flags[:directory] or file.flags[:volume]
    #check empty
    fa_files = Flashair.do_ls(ip, target)
    puts "directory_check: #{fa_files}" if opt[:debug]

    if fa_files.nil?
      return false
    end
    if fa_files.length != 0
      puts "directory is not empty: #{target}"
      return false
    end
  end

  success = Flashair.do_rm(ip, file)
  unless success
    puts Flashair.get_error
  end

  success
end

options = {}
options[:debug] = false

params = ARGV.getopts('', 'debug', 'ip:')

options[:debug] = true if params["debug"]

if params["ip"]
  ip = params["ip"]
else
  puts "--ip <addr> is required"
  exit 1
end

exit 1 if ARGV.length < 1

target = ARGV

if options[:debug]
  Flashair.set_debug(true)
  puts "target: #{target}"
end

target.each do |elm|
  if elm[elm.length-1] == '/'
    str = elm.chop
  else
    str = elm
  end
  exit 1 unless do_remove(ip, str, options)
end
