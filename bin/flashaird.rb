#!/usr/bin/ruby
PIDFILE="/var/run/flashaird.pid"
DAEMON=true

REPO_PATH = File.dirname(__FILE__)
require "#{REPO_PATH}/../lib/flashair.rb"

require "#{REPO_PATH}/config.rb"
# config.rb
#
#CONFIG= [
#  {
#    :address => "192.168.0.2",
#    :mailto => "mailaddress@localhost",
#    :dir => "/output/directory/path"
#    :file_regexp => "*.JPG"
#  },
#  ...
#]
#

class Client
  CMD_CHMOD = "/bin/chmod"
  CMD_SMTP = "/usr/local/sbin/ssmtp"
  CMD_FLASHAIR = "#{File.dirname(__FILE__)}/flashair.rb"
  PING_INTERVAL = 30
  PING_CONN_CNT = 3
  PENDING_TIME = 60 * 30 # 30min
  MAIL_FROM="root@flashaird.localhost"

  #CMD_CHMOD = "/bin/echo"
  #CMD_SMTP = "/bin/echo"
  #CMD_FLASHAIR = "/bin/echo"
  #PENDING_TIME=5

  attr_reader :next, :pid

  def initialize(cfg)
    @addr = cfg[:address] || "0.0.0.0"
    @mailto = cfg[:mailto] || "drop@localhost"
    @dir = cfg[:dir] || "/dev/null"
    @regexp = cfg[:file_regexp] || "none"
    @state = :search
    @ping = 0
    @next = 0
    @pid = -1
    @error = ""
  end

  def exec
    next_up = 1
    case @state
    when :search
      found = _ping @addr
      if found
        @ping += 1
        next_up = 1
      else
        @ping = 0
        next_up = PING_INTERVAL
      end

      if @ping > PING_CONN_CNT
        @state = :download
        @ping = 0
      end
      @state = :download if @ping > PING_CONN_CNT
    when :download
      @pid = fork do
        _download
      end

      next_up = PENDING_TIME
      @state = :pending

    when :pending
      Process.waitpid(@pid)
      @pid = -1
      @state = :search
    end

    # update next up
    @next = Time.now.to_i + next_up
  end

  def _ping addr
    cmd="ping -c 1 #{addr} > /dev/null 2> /dev/null"
    puts cmd
    system(cmd)
  end

  def _download
    reg = Regexp.new(@regexp)
    files = get_files(@addr, '/', reg)

    str = Time.now.strftime("%Y%m%d-%H%M%S")
    out_dir = "#{@dir}/#{str}"
    mailtxt = "#{@dir}/#{@mailto}.txt"

    puts "out_dir: #{out_dir}" unless DAEMON
    begin
      File.open(mailtxt, "w") do |f|
        f.puts("To: #{@mailto}")
        f.puts("From: #{MAIL_FROM}")
        f.puts("Subject: flashair #{Time.now}")
        f.puts("") # blank

        if files.nil?
          puts @error if files.nil?
          break
        end

        begin
          FileUtils.mkdir_p(out_dir)
        rescue => e
          f.puts e
          break
        end

        f.puts "output: #{out_dir}"

        files.each do |elm|
          success = Flashair.do_cp(@addr, elm, "#{out_dir}/#{elm.name}")
          unless success
            f.puts "cp error : #{Flashair.get_error}"
            break
          end

          success = Flashair.do_rm(@addr, elm)
          unless success
            f.puts "rm error : #{Flashair.get_error}"
            break
          end

          f.puts elm.name
        end
      end
    rescue => e
      puts e unless DAEMON
    end

    #system("#{CMD_CHMOD} -R 777 #{out_dir}")
    system("#{CMD_SMTP} #{@mailto} < #{mailtxt}")
  end

  def get_files(ip, dir, regexp)
    files = Flashair.do_ls(ip, dir)
    if files.nil?
      @error = Flashair.get_error
      return nil
    end

    rv = []
    files.each do |f|
      if f.flags[:directory] or f.flags[:volume]
        tmp0 = get_files(ip, "#{f.path}/#{f.name}", regexp)
        if tmp0.nil?
          @error = Flashair.get_error
          return nil
        else
          rv += tmp0
        end
      end

      rv << f if f.name =~ regexp
    end

    rv
  end
end

#
# main
#

clients = []
CONFIG.each do |elm|
  clients << Client.new(elm)
end

# signal
sigint=false
sigterm=false

Signal.trap("INT"){|signo| sigint=true; raise "signal #{signo}"}
Signal.trap("TERM"){|signo| sigterm=true; raise "signal #{signo}"}

# daemonize
Process.daemon if DAEMON
File.open(PIDFILE, "w") {|f| f.puts(Process.pid)}

running = true
while running
  now = Time.now.to_i

  clients.each do |c|
    c.exec if c.next <= now
  end

  # Sleep
  next_min = now + 60
  clients.each do |c|
    next_min = c.next if c.next < next_min
  end

  s = next_min - now
  begin
    sleep s if s > 0
  rescue => e
    # do nothing
  end

  # terminate
  if sigterm or sigint
    puts "wait child proc"
    clients.each do |c|
      Process.waitpid c.pid if c.pid != -1
    end

    running = false
  end
end

File.unlink(PIDFILE)
