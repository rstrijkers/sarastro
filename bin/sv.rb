#!/usr/bin/env ruby
#
# Copyright (C) 2012 Rudolf Strijkers <rudolf.strijkers@tno.nl>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# Simple process management with control via a named pipe, mainly for 
# automatically restart the netapp. The programs should not daemonize.
#
#   redis: redis-server ./etc/redis.conf
#   sarastro_netapp: ruby -I lib ./bin/sarastro_netapp.rb
#
# format: 
#   echo start name keep_alive command > pipe
#   echo [stop|restart] name > pipe
#   echo list > pipe
#   echo quit > pipe
#
# start sv.rb with -d to daemonize the supervisor and write out pid. When 
# daemonized, sv will write out stderr and stdout to file with the process
# name. On finish, sv moves the output to name.done.
#
# TODO: 
#   - add logging of events to separate files
#   - read process list and configuration from a file on startup
#

require 'logger'

if ARGV[0] == "-d" # daemonize
  $log = Logger.new("sv.log")
else
  $log = Logger.new(STDOUT)
end

$max_log_size = 1000000
$daemon = false
$pipe = "sv.cmd"
$pidfile = "sv.pid"
$io_list = []
$io_info = {}

def quit
  $log.debug "Closing pipe"
  $input.close unless $input.closed?
  $log.debug "Removing named pipe and pid file..."
  `rm -f #{$pipe}`
  `rm -f #{$pidfile}`
  
  flush_processes
  
  $log.debug "Bye..."
end

def display
  $log.info "name\tpid\tkeep_alive\tcmd"
  $io_info.each_pair {|k,v|
    $log.info "#{v[:name]}\t#{k}\t#{v[:keep_alive]}\t\t#{v[:cmd]}"
  }
end

def flush_processes
  $log.debug "Killing child processes..."
  $io_list.each {|io| kill(io) }
end
  
def kill(io)
 # begin
#    Process.kill("SIGTERM", io.pid)
#    Process.kill("SIGINT", io.pid)
#    Process.kill("SIGKILL", io.pid)
#  rescue
    # then just do it like this...
    kill_hierarchy(io.pid)
 # end
  io.close unless io.closed?
end

def kill_hierarchy(pid)
  # if there is no pid, we are done
  pids = []
  new_pid = pid
  begin
    tmp = `ps -o pid --no-headers --ppid #{new_pid}`.split("\n")
    break if tmp.empty?
    pids.push tmp[0]
    new_pid = tmp[0]
  end while true

  # remove duplicates and make into list
  pids = pids.flatten.uniq
  $log.debug "found pids: #{pids.inspect}"

  begin
    cp = pids.pop
    $log.debug "kill child: #{cp}"
    `sudo kill -9 #{cp}`
    break if pids.empty?
  end while true unless pids.empty?
  $log.debug "kill parent: #{pid}"
  `sudo kill -9 #{pid}`
end


def clear_log(file)
  `rm -rf #{file}`
end

def start(msg)
  start, name, keep_alive, cmd = msg.split(/\s/, 4)
  $log.debug "<<<start#{keep_alive == "1" ? " (keep_alive)" : ""}: (#{name}) #{cmd}"

  # find if name exists... o(n)
  found = false
  $io_info.each_pair {|k,v|
    if v[:name] == name
      found = true
      break
    end
  }

  unless found
    clear_log(name) if $daemon
  
    io = IO.popen(["sh", "-c", cmd, :err=>[:child, :out]])
    
    $io_info[io.pid] = {:cmd => cmd, :name => name, :started => Time.now, :keep_alive => keep_alive == "1" ? true : false}
    $io_list << io
  else
    $log.debug "Process already exists with name #{name}"
  end
end

# must find the io object... o(n)
def clean(io)
  return if io.class == File # already closed on quit
  
  file = $io_info[io.pid][:name]
  if $io_info[io.pid][:keep_alive]
    restart("restart #{file}")
  else
    $log.debug "Cleaning up for pid #{io.pid}"
    $io_list.delete(io)
    $io_info.delete(io.pid)
    io.close unless io.closed?
    `mv #{file} #{file}.done`
  end
end

def stop(msg)
  name = msg.match(/\s[^\s]+/).to_s.strip

  # lookup name
  pid = nil
  $io_info.each_pair {|k,v| 
    if name == v[:name]
      pid = k 
      break
    end
  }

  if pid
    info = $io_info.delete(pid)
    $log.debug "<<<stop: (#{info[:name]}:#{pid}) #{info[:cmd]}"

    kill($io_list.delete_at($io_list.index {|io| io.pid == pid}))
  else
    $log.debug "no process with name #{name}"
  end  
end

def restart(msg)
  name = msg.match(/\s[^\s]+/).to_s.strip

  info = nil
  $io_info.each_pair {|k,v| 
    if name == v[:name]
      info = v
      break
    end
  }
  
  $log.debug "<<<restarting: (#{info[:name]})"
  stop("stop #{info[:name]}")
  
  if info
    delta = Time.now - info[:started]
    if delta > 5
      start("start #{info[:name]} #{info[:keep_alive] ? 1 : 0} #{info[:cmd]}")
    else
      $log.debug "Not restarting process: restart was triggered in #{delta} seconds"
    end
  else
    $log.debug "No command to start"
  end
end

def process_input(msg)
  $log.debug "<<<cmd: #{msg}"

  case msg.match(/[^\s]+/).to_s
  when "start"
    start(msg)
  when "stop"
    stop(msg)
  when "restart"
    restart(msg)
  when "list"
    display
  when "quit"
    quit    
    return nil # breaks out of select loop
  end
end

def process_event(msg, io)
  file = $io_info[io.pid][:name]
  unless $daemon
    $log.debug ">>>#{file}: #{msg}"
  else
    # truncate the file if it's too large...
    mode = "a"
    if File.exist? file
      if (File.size? file).to_i > $max_log_size
        mode = "w"
      end
    end

    File.open(file, mode) {|f| f.puts(msg) }    
  end
end

def check_pid
  unless File.exist? $pidfile
    Process.daemon(true, true)
    
    File.open($pidfile, 'w') {|f| f.write(Process.pid) }
  else
    $log.debug "Pid file exists, supervisor either running or garbage."
    exit
  end
end

Signal.trap("SIGINT") { quit }
Signal.trap("SIGTERM") { quit }

if ARGV[0] == "-d" # daemonize
  $daemon = true
  $log.debug "Becoming daemon!"
  check_pid
end

# use simple file based $input, so that commands can be sent as:
# echo start sarastro ./bin/sarastro_app.rb > $pipe
# echo start vtun1 "sudo vtund -n -f test/vtun2 cloud 192.168.136.135 2>&1" > $pipe
`mkfifo #{$pipe}` unless File.exist?($pipe)
`rm -f $pipe`
$input = open($pipe, "r+") # the r+ means we don't block

$log.debug "Entering event loop..."

# having the kernel handling the timeout is better, because it uses no cpu time.
# on timeout, nil will be returned.
loop {
  begin
    result = IO.select([$input] + $io_list, nil, nil, 10) 
    next if result.nil?

    result[0].each {|io|
    	begin 	  
    	  msg = io.gets
    	  unless msg.nil?  	  
      	  msg = msg.strip
    	  
          unless io.pid # got a message from the named pipe
      	    process_input(msg)     	    
      	  else 
      	    process_event(msg, io)
          end
        else
          raise "Process closed io unexpectedly"
        end
      rescue Exception => e
    		$log.debug "Process #{io.pid} ended: #{e.message}"
    		clean(io)  		
    		break 
    	end
    }
  rescue 
    # do nothing, timeout
  end
}

quit