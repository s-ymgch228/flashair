#!/usr/bin/ruby
# coding: utf-8

require 'net/http'
require 'uri'
require 'optparse'
require 'fileutils'

module Main
  extend self

  def main(opt, args)
    file_count = 0

    unless opt.class == Hash and
      args.class == Array and
      args.size == 1
      usage
    end

     remove = true
     remove = false if opt["remove"] == "off"
     overwrite = false
     overwrite = true if opt["overwrite"] == "on"
     filename = opt["file"] || "DSC_*"
     dest_path = opt["dest"] || "#{Dir.pwd}/"

    fa = Flashair.new(args[0])
    files = fa.get_all_files(filename)

    if files.empty?
      puts "no file"
      exit 1
    end

    out_dir = get_output_dir(dest_path, overwrite)
    if out_dir.nil?
      puts "no output dir"
      exit (1)
    end
    puts "download to #{out_dir}"

    FileUtils.mkdir_p(out_dir)

    files.each do |file|
      outfile = file[:path].gsub(/\//,'_')
      outfile[0] = '' if outfile[0] == '_'

      print "download #{file[:path]} ==> #{outfile}"

      body = fa.get_file_body(file)

      File.open("#{out_dir}/#{outfile}", 'w+b') do |f|
        f.write(body)
      end

      if remove
        fa.remove_file(file)
        puts " (move)"
      else
        puts " (copy)"
      end
    end

    0
  end

  def get_output_dir(path, overwrite = false)
    today = Time.now.strftime("%Y%m%d")

    for cnt in 0..63
      dir = "#{path}#{today}_#{cnt}"

      return dir unless File.exists?(dir)
      return dir if overwrite
    end

    nil
  end

  def usage
    puts "#{$0} [options] <ip addr>"
    puts "  --remove    {on|off}:on"
    puts "  --overwrite {on|off}:off"
    puts "  --file      {<filename regexp>}"
    puts "  --dest      {<destination path>}:$PWD/"
    exit(1)
  end
end

class Flashair
  CMD_GET_FILELIST = 100
  FILE_ATTRIBUTES = [
    {:flag => 0x01, :attr => :readonly},
    {:flag => 0x02, :attr => :hidden},
    {:flag => 0x04, :attr => :system},
    {:flag => 0x08, :attr => :volume},
    {:flag => 0x10, :attr => :directory},
    {:flag => 0x20, :attr => :archive}
  ]

  FILE_DATES = [
    {:key => :year, :offset => 9, :mask => 0x7F},
    {:key => :mon,  :offset => 5, :mask => 0x0F},
    {:key => :day,  :offset => 0, :mask => 0x1F}
    ]
  FILE_TIMES = [
    {:key => :hour, :offset => 11, :mask => 0x1F},
    {:key => :min,  :offset => 5,  :mask => 0x3F},
    {:key => :sec,  :offset => 0,  :mask => 0x1F}
  ]

  def initialize(ip, port = 0)
    @addr = ip
    if port != 0
      @port = ":#{port}"
    else
      @port = ""
    end
  end

  def get_file_list(path = "/")
    filelist = []
    param = {"op" => CMD_GET_FILELIST, "DIR"=> path}
    txt = _access("/command.cgi", param)
    txt.each_line do |l|
      file={}
      a = l.split(",")
      next if a.length != 6
      parent = a[0]
      if parent.length == 0
        parent = "/"
      end

      file[:path] = "#{parent}/#{a[1]}"
      file[:name] = a[1]
      file[:size] = a[2]

      flags = a[3].to_i
      FILE_ATTRIBUTES.each do |h|
        key = h[:attr]
        if (flags & h[:flag]) == 0
          file[key] = false
        else
          file[key] = true
        end
      end

      date = a[4].to_i
      FILE_DATES.each do |h|
        file[h[:key]] = (date >> h[:offset]) & h[:mask]
      end
      file[:year] += 1980

      time = a[5].to_i
      FILE_TIMES.each do |h|
        file[h[:key]] = (time >> h[:offset]) & h[:mask]
      end

      filelist << file
    end

    filelist
  end

  def get_all_files(regexp_str, root = "/DCIM")
    regexp = Regexp.new(regexp_str)
    filelist = []
    get_file_list(root).each do |file|
      if file[:directory]
        subdir = get_all_files(regexp, file[:path])
        subdir.each do |elm|
          filelist << elm
        end
      else
        filelist << file if file[:name] =~ regexp
      end
    end

    filelist
  end

  def get_file_body(file)
    return _access(file[:path])
  end

  def remove_file(file)
    success = true
    print "protect on"
    out = _access("/upload.cgi", {"WRITEPROTECT"=>"ON"})
    if out.include?("Error")
      puts " failed"
      success = false
      return success
    end

    print ", remove"
    out = _access("/upload.cgi", {"DEL"=> "#{file[:path]}"})
    if out.include?("Error")
      puts "failed"
      success = false
    end

    print ", and protect off"
    out = _access("/upload.cgi", {"WRITEPROTECT"=>"OFF"})
    if out.include?("Error")
      puts "failed"
      success = false
    end
    puts ""

    success
  end

  def _access(path, param = nil)
    uri = URI.parse("http://#{@addr}#{@port}#{path}")
    uri.query = URI.encode_www_form(param) unless param.nil?
    req = Net::HTTP::Get.new(uri)

    res = Net::HTTP.start(uri.host, uri.port) { |http|
      http.request(req)
    }

    res.body
  end
end

## main
opt = ARGV.getopts('h', 'remove:', 'overwrite:', "file:", "dest:")
arg = ARGV
Main.main(opt, arg)
