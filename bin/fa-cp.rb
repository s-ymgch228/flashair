#!/usr/bin/ruby
require 'optparse'

REPO_PATH = File.dirname(__FILE__)
require "#{REPO_PATH}/../lib/flashair.rb"

def do_copy(ip, src, dst, opt)
  src_dir = File.dirname(src)
  src_file = File.basename(src)

  if File::ftype(dst) == "directory"
    dst_path = "#{dst}/#{src_file}"
  else
    dst_path = dst
  end

  # Search file in FlashAir
  fa_files = Flashair.do_ls(ip, src_dir)
  return false if fa_files.nil?

  fa_file = nil
  fa_files.each do |f|
    if f.name == src_file
      fa_file = f
      break;
    end
  end

  return false if fa_file.nil?

  success = Flashair.do_cp(ip, fa_file, dst_path)
  unless success
    puts Flashair.get_error
  end

  success
end

options = {}
options[:debug] = false

params = ARGV.getopts('debug', 'ip:')

options[:debug] if params["debug"]

if params["ip"]
  ip = params["ip"]
else
  puts "--ip <addr> is required"
  exit 1
end

exit 1 if ARGV.length < 2

src = ARGV
dst = src.pop

if options[:debug]
  puts "src: #{src}"
  puts "dst: #{dst}"
  Flashair.set_debug(true)
end

if File::ftype(dst) != "directory" and src.length != 1
  puts "Destination is not a directory"
  exit 1
end


src.each do |elm|
  exit 1 unless do_copy(ip, elm, dst, options)
end
