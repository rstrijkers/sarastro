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
#
# 

module VIC
  module TunnelController   
    VTUN_SERVER = "vtun:server"
    VTUN_CLIENT = "vtun:client"
    
    def servers
      REDIS.hgetall(VTUN_SERVER)
    end
    
    def clients
      REDIS.hgetall(VTUN_CLIENT)
    end
    
    # start client (dest)
    #   -> create configuration for port
    def create_client(dest, port)
      return nil unless port && dest
          
      p, tap, path = create_configuration(port)
      id = "c#{tap.sub("vi","")}-#{dest}"
      
      data = {
        :port => port, 
        :tap => tap,
        :conf => path,
        :dest => dest,
        :id => id
      }
      
      if port.to_i > 0
        start_vtun(id, "sudo vtund -f #{path} -n -p vi #{dest}")
        REDIS.hset(VTUN_CLIENT, "#{port}/#{dest}", data.to_json)
      else
        return -1
      end
            
      data
    end
        
    # start server (configuration)
    def create_server
      port, tap, path = create_configuration
      # was: id = "s#{port}"
      id = tap.sub("vi","s")
      data = {}
      
      puts "port: #{port}, tap: #{tap}, path: #{path}"
        
      data = {
        :port => port, 
        :tap => tap,
        :conf => path,
        :id => id
      }

      if port.to_i > 0
        pid = start_vtun(id, "sudo vtund -s -f #{path} -n")
        
        REDIS.hset(VTUN_SERVER, port, data.to_json)            
      else
        return {:port => -1}
      end

      data
    end

# ----------------------------------------------------------------------------
#   Manage processes
# ----------------------------------------------------------------------------

    # server keys are by port, client by port:dest 
    def stop_vtun(type, key)
      puts "stop tunnel: #{type}, key: #{key}"      
      entry = j(REDIS.hget("vtun:#{type}", key))
      puts "entry: #{entry}"
      if entry
        write_to_pipe("stop #{entry[:id]}") 
        `rm -rf #{entry[:id]}`
        REDIS.hdel("vtun:#{type}", key)
      end    
    end
    
    def start_vtun(name, string)
      write_to_pipe("start #{name} 0 #{string}")
    end
    
    # use sv.rb to manage vtun processes!
    def write_to_pipe(string)
      output = open("sv.cmd", "w+") # the w+ means we don't block
      output.puts string
      output.flush # do this when we're done writing data
      output.close
    end

# ----------------------------------------------------------------------------
  
    # create configuration
    #   -> unique tap interface
    #   -> unique port
    def create_configuration(port = nil)
      if port.nil?
        port = take_port
      end
      tap = take_tap
      
      # better to write to temp file
      path = write_to_tempfile <<-EOF
      options {
        port #{port};  
      }

      vi {
        password aeunsth23134132nstantoetuoehousntetnsoaentu32432402394oenutoeoauht234sn123nthoeansteoaun;
        type ether;
        proto udp;
        device #{tap};
        keepalive yes;
        up {
          ifconfig "#{tap} up mtu 1450";
        }
      }
      EOF
      
      [port, tap, path]
    end
    
    # get unique tap interface. should support reuse(!)
    def take_port
      port = -1
      
      # set with taken ports
      available = REDIS.smembers("port:available")
      if available.empty?
        REDIS.multi do
          (5900..6000).each {|p| REDIS.sadd("port:available", p)}          
        end
      end
      choice = REDIS.sdiff("port:available", "port:taken")
      if choice.empty?
        puts "limit! cannot support > 100 tunnels"
      else
        port = choice[0]
        REDIS.sadd("port:taken", port)
      end
      port
    end
        
    # get unique port. should support reuse(!)
    def take_tap
      tap = -1
      
      # set with taken ports
      available = REDIS.smembers("tap:available")
      if available.empty?
        REDIS.multi do
          (5900..6000).each {|p| REDIS.sadd("tap:available", p)}          
        end
      end
      choice = REDIS.sdiff("tap:available", "tap:taken")
      if choice.empty?
        puts "limit! cannot support > 100 tap interfaces"
      else
        tap = choice[0]
        REDIS.sadd("tap:taken", tap)
      end
      "vi#{tap}"
    end
    
    def write_to_tempfile(string)
      file = Tempfile.new("vtun")
      file.write(string)
      file.close
      file.path
    end
    
    def j(string)
      begin
        return JSON.parse(string, :symbolize_names => true)
      rescue
        return nil
      end
      nil
    end
  end
end

# address management
#
# monitoring management
#   load
#   steal time
#   network statistics
#     latency
#     bw
#     
  