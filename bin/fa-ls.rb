#!/usr/bin/ruby
require 'optparse'

REPO_PATH = File.dirname(__FILE__)
require "#{REPO_PATH}/../lib/flashair.rb"

options = {}

def print_ls(ip, dir, file, opt)
  path = ""
  flags = ""
  size = ""
  date = ""
  time = ""

  #puts "dir=#{dir}"

  files = Flashair.do_ls(ip, dir)
  return false if files.nil?

  files.each do |e|
    out = false
    recursive = false

    if file.nil?
      out = true
    elsif file == e.name
      if e.flags[:directory] or e.flags[:volume]
        recursive = true
      else
        out = true
      end
    end
    if opt[:recursive] and (e.flags[:directory] or e.flags[:volume])
      recursive = true
    end

    #puts opt
    #puts recursive

    path = "#{e.path}/" if opt[:path]
    if (opt[:flags])
      out = true

      flags = "rhsvda\t"
      flags[0] = '-' unless e.flags[:readonly]
      flags[1] = '-' unless e.flags[:hidden]
      flags[2] = '-' unless e.flags[:system]
      flags[3] = '-' unless e.flags[:volume]
      flags[4] = '-' unless e.flags[:directory]
      flags[5] = '-' unless e.flags[:archive]
    end

    if opt[:size]
      out = true

      size = "#{e.size}\t"
      size += "\t" if size.length <= 8
    end

    if opt[:date]
      out = true

      date = "#{e.date[:year]}/#{e.date[:mon]}/#{e.date[:day]}\t"
      time = "#{e.time[:hour]}:#{e.time[:min]}:#{e.time[:sec]}\t"
      time += "\t" if time.length <= 8
    end

    name = e.name

    if out
      puts "#{flags}#{size}#{date}#{time}#{path}#{name}"
    end

    if recursive
      if opt[:recursive]
        puts "" # blank
        puts "#{name}:"
      end

      success = print_ls(ip, "#{e.path}/#{e.name}", nil, opt)
      return success unless success
    end
  end

  true
end

# option parse

options[:path] = false
options[:flags] = false
options[:size] = false
options[:date] = false
options[:recursive] = false

params = ARGV.getopts('','debug', 'long', 'ip:', 'path', 'recursive')
#puts params

if params["ip"]
  addr = params["ip"]
else
  puts "Error: no '--ip <address>' option"
  exit 1
end

Flashair.set_debug(true) if params["debug"]
if params["long"]
  options[:path] = true
  options[:flags] = true
  options[:size] = true
  options[:date] = true
end

options[:path] = true if params["path"]
options[:recursive] = true if params["Recursive"]

targets = ARGV || "/"
targets.each do |t|
  if t[0] == '/'
    t0 = t
  else
    t0 = "/#{t}"
  end

  dir = File.dirname(t0)
  file = File.basename(t0)
  file = nil if dir == file
  success = print_ls(addr, dir, file, options)
  unless success
    puts "Error:"
    puts Flashair.get_error
    exit 1
  end
end

exit 0
