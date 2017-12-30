#!/usr/bin/ruby
# coding: utf-8

require 'net/http'
require 'uri'
require 'fileutils'

module Flashair
  @debug = false
  @error = nil

  attr_accessor :debug
  attr_accessor :error

  class << self
    CMD_GET_FILELIST = 100

    def set_debug(enable)
      @debug = enable
    end

    def get_error
      return "No error" if @error.nil?
      return @error
    end

    def do_ls(ip, target_path)
      rv = []

      param = {"op" => CMD_GET_FILELIST, "DIR" => target_path}
      text = _access(ip, "/command.cgi", param)
      return nil if text.nil?

      text.each_line do |l|
        f = FlashairFile.new
        a = l.chop.split(",")

        # skip an incomplete line
        if a.length != 6
          puts "skip: #{a}" if @debug_ls
          next
        end

        f.set_path(a[0])
        f.set_name(a[1])
        f.set_size(a[2])
        f.set_flags(a[3])
        f.set_date(a[4])
        f.set_time(a[5])

        rv << f
      end

      rv
    end

    def do_cp(ip, src, dst_str)
      fullpath = "#{src.path}/#{src.name}"
      file = _access(ip, fullpath)

      if file.nil?
        @error = "file not found"
        return false
      end

      begin
        File.open(dst_str, "w+b") do |f|
          f.write(file)
        end
      rescue => e
        puts e if @debug
        @error = e
        return false
      end

      true
    end

    def do_rm(ip, file)
      out = _access(ip, "/upload.cgi", {"WRITEPROTECT"=>"ON"})
      return false if out.nil?
      if out.include?("Error")
        @error = "Write protect ON: #{out}"
        return false
      end

      path = "#{file.path}/#{file.name}"
      out = _access(ip, "/upload.cgi", {"DEL"=> path})
      return false if out.nil?
      if out.include?("Error")
        @error = "delete: #{out}"
        return false
      end

      out = _access(ip, "/upload.cgi", {"WRITEPROTECT"=>"OFF"})
      return false if out.nil?
      if out.include?("Error")
        @error = "Write protect OFF: #{out}"
        return false
      end

      true
    end

    def _access(ip, fullpath, param = nil)
      uri = URI.parse("http://#{ip}#{fullpath}")
      uri.query = URI.encode_www_form(param) unless param.nil?


      begin
        req = Net::HTTP::Get.new(uri)
        res = Net::HTTP.start(uri.host, uri.port) { |http|
          http.request(req)
        }
      rescue => e
        puts e if @debug
        @error = e
        return nil
      end

      status = res.code.to_i
      return nil if status < 200 || 300 < status

      res.body
    end
  end

end

class FlashairFile
  attr_reader :name, :path, :size
  attr_reader :flags, :date, :time

  FILE_ATTRIBUTES = [
    {:flag => 0x01, :attr => :readonly},
    {:flag => 0x02, :attr => :hidden},
    {:flag => 0x04, :attr => :system},
    {:flag => 0x08, :attr => :volume},
    {:flag => 0x10, :attr => :directory},
    {:flag => 0x20, :attr => :archive}
  ]

  FILE_DATE = [
    {:key => :year, :offset => 9, :mask => 0x7F},
    {:key => :mon,  :offset => 5, :mask => 0x0F},
    {:key => :day,  :offset => 0, :mask => 0x1F}
    ]
  FILE_TIME = [
    {:key => :hour, :offset => 11, :mask => 0x1F},
    {:key => :min,  :offset => 5,  :mask => 0x3F},
    {:key => :sec,  :offset => 0,  :mask => 0x1F}
  ]

  def initialize
    @name = ""
    @path = ""
    @size = 0
    @flags = {}
    @date = {}
    @time = {}
  end

  def set_name(name)
    @name = name
  end

  def set_path(path)
    @path = path
  end

  def set_size(size_str)
    @size = size_str.to_i
  end

  def set_flags(flags_str)
      rv = {}
      flags = flags_str.to_i

      FILE_ATTRIBUTES.each do |h|
        key = h[:attr]
        if (flags & h[:flag]) == 0
          rv[key] = false
        else
          rv[key] = true
        end
      end

      @flags = rv
  end

  def set_date(date_str)
    rv = {}
    date = date_str.to_i

    FILE_DATE.each do |h|
      rv[h[:key]] = (date >> h[:offset]) & h[:mask]
    end
    rv[:year] += 1980

    @date = rv
  end

  def set_time(time_str)
    rv = {}
    time = time_str.to_i

    FILE_TIME.each do |h|
      rv[h[:key]] = (time >> h[:offset]) & h[:mask]
    end

    @time = rv
  end
end
