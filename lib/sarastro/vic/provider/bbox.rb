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
#

# we already have an image setup.
module VIC
  class BBoxProvider
    def initialize(settings, cpid)
      @cpid = cpid
      @parameters = settings      
      @credentials = settings[:credentials]
      @connection = Fog::Compute.new(@credentials)
    end
    
    
    # XXX: refactor, ec2 & bbox code exactly the same!
    def wait_for(userid, vid, id, reqid)
      if s = @connection.servers.get(id)
        # wait for public ip address
        s.wait_for { puts "waiting for bbox vm (vid: #{vid} id: #{id})..."; ready? || s.state == "deleted" || s.state == 'failed' || s.state == 'terminated'}
        created = Time.now
        public_ip = nil
       
        if s.state == 'deleted' || s.state == 'terminated' || s.state == 'failed'
          id = s.id
          kill(s.id)
          return {:server_id => id, :created => created, :cpid => @cpid, :msg => "bogus"}
        end
       
       
# XXX: Refactor!!!
        # check if there is already an IP
        if s.cloud_ips[0]
          puts "found public ip address: #{s.cloud_ips[0]["public_ip"]}"
          
          # rewrite the data
          append = {:location => s.zone["handle"], :server_id => id, :public_ip_address => s.cloud_ips[0]["public_ip"], :ts_sshable => Time.now, :created => created, :cpid => @cpid}      
          
        else

        stop = false
        while !stop
          begin
            puts "looping... cloudip"
            
            # loop through the cloud ips to find an unmapped ip
            # XXX: this is done in parallel, which can lead to conflicting
            # ip mappings. Just catch the rescue and try again.
            
            block = true

            # set mutex
            while block
              unless REDIS.get("bbox:cloudip:mutex") == "busy"
                REDIS.set("bbox:cloudip:mutex", "busy")
                puts "blocking bbox cloud ip create: #{id}"

                # race condition
#
#                found_ip = nil
#                @connection.cloud_ips.each {|ip|
#                  if ip.status == "unmapped"
#                    found_ip = ip
#                    break
#                  end
#                }
#
#                puts "found ip is: -#{found_ip}-"
#
#                # if none is found create an ip
#                unless found_ip
#                  puts "creating cloud ip"
                  found_ip = @connection.create_cloud_ip 
                  puts "created IP: #{found_ip}"
              
                  @connection.map_cloud_ip(found_ip["id"], {"destination" => s.interfaces[0]["id"]})                          
                  public_ip = found_ip["public_ip"]
#                else
#                  puts "got IP: #{found_ip.id} for interface #{s.interfaces[0]["id"]}"          
#                  @connection.map_cloud_ip(found_ip.id, {"destination" => s.interfaces[0]["id"]})
#                  public_ip = found_ip.public_ip
#                end
#                # race condition
                puts "freeing mutex: #{id}"
                REDIS.set("bbox:cloudip:mutex", "free")                
                block = false
              else
                sleep 1              
                puts "waiting for mutex: #{id}"
              end
            end
            
            # end of mutex
            
            stop = true

          rescue Excon::Errors::Conflict
            stop = false
            puts "address conflict"
          rescue Excon::Errors::Forbidden
            stop = true
            puts "cannot create IP: kill the vm"
          end
        end

          kill(s.id) unless wait_for_ssh(public_ip)
          
          append =  {:location => s.zone["handle"], :server_id => s.id, :public_ip_address => public_ip, :ts_sshable => Time.now, :created => created, :cpid => @cpid}   
        end
# XXX: end Refactor!!!

        netdata = REDIS.hget("queue:netapp:data", reqid)
        data = JSON.parse(netdata, :symbolize_names => true) if netdata
        REDIS.hset("queue:netapp:data", reqid, data.merge({:status => "done", :output => append}).to_json) if data
      else
        puts "server with id #{id} does not exist" 
        
        REDIS.hdel("queue:netapp:data", reqid)
      end
      
      # remove the entry once we have an ip address, the vm is up and will be 
      # associated to the node.
      REDIS.hdel("#{userid}:vi:#{vid}:transient", reqid)

      # add it to the list of netapps
      REDIS.sadd("#{userid}:vi:#{vid}:netapps", reqid) unless REDIS.sismember("#{userid}:vi:#{vid}:netapps", reqid)
    end
        
    # XXX: refactor, same as ec2
    def wait_for_ssh(ip)
      username = "rudolf"
      
      # XXX: from Fog: wait for aws to be ready
      Timeout::timeout(180) do
        begin
          Timeout::timeout(8) do
            Fog::SSH.new(ip, username, {:timeout => 4}).run('pwd')
            return true
          end
        rescue Errno::ECONNREFUSED
          sleep(2)
          puts "#{self.class}: Connectien refused #{ip}"
          retry
        rescue Net::SSH::AuthenticationFailed, Timeout::Error
          retry
        rescue Net::SSH::Disconnect
          puts "#{self.class}: VM probably gone.... stopping."          
        end        
      end
      
      nil
    end        
        
    # right now there are two zones and one region... we don't make a difference now
    # unlike amazon, we don't have to select different images...
    def create_netapp(userid, vid, reqid, params)
      bbparams = {}
      public_ip = nil
      zone = params.delete(:zone)
      if zone # convert zone handle to id
        @connection.zones.each {|z| 
          if z.handle == zone
            bbparams[:zone_id] = z.id
            break
          end        
        }
      end        
      bbparams[:image_id] = params.delete(:imageid)
      bbparams[:flavor_id] = 'nano'
      
      puts "Creating #{self.class} vm with parameters #{bbparams}"
  
      server = @connection.servers.create(bbparams)

      REDIS.hset("#{userid}:vi:#{vid}:transient", reqid, {:server_id => server.id, :cpid => @cpid}.to_json)
        
      server.wait_for { puts "#{self.class}: waiting for vm #{server.id}..."; ready? || server.state == 'deleted' || server.state == 'terminated' || server.state == 'failed' }
      created = Time.now
  
      if server.state == 'deleted' || server.state == 'terminated' || server.state == 'failed'
        id = server.id 
        kill(server.id)
        return {:location => zone, :server_id => id, :created => created, :cpid => @cpid, :msg => "bogus"}
      end

      # loop through the cloud ips to find an unmapped ip
      stop = false
      while !stop
        begin
          puts "looping through cloudips"
          # loop through the cloud ips to find an unmapped ip
          # XXX: this is done in parallel, which can lead to conflicting
          # ip mappings. Just catch the rescue and try again.
          
          block = true

          # set mutex
          while block
            unless REDIS.get("bbox:cloudip:mutex") == "busy"
              REDIS.set("bbox:cloudip:mutex", "busy")
              puts "got mutex: #{id}"
              
              # race condition

#              found_ip = nil
#              @connection.cloud_ips.each {|ip|
#                if ip.status == "unmapped"
#                  found_ip = ip
#                  break
#                end
#              }
#
#              puts "found ip is: -#{found_ip}-"
#
#              # if none is found create an ip
#              unless found_ip
                puts "creating cloud ip"
                found_ip = @connection.create_cloud_ip 
                puts "created IP: #{found_ip}"
            
                @connection.map_cloud_ip(found_ip["id"], {"destination" => server.interfaces[0]["id"]})                          
                public_ip = found_ip["public_ip"]
#              else
#                puts "got IP: #{found_ip.id} for interface #{server.interfaces[0]["id"]}"          
#                @connection.map_cloud_ip(found_ip.id, {"destination" => server.interfaces[0]["id"]})
#                public_ip = found_ip.public_ip
#              end
#              # race condition
              REDIS.set("bbox:cloudip:mutex", "free")   
              puts "freeing mutex: #{id}"             
              block = false
            else
              sleep 1  
              puts "waiting for mutex: #{id}"            
            end
          end
          
          # end of mutex
          
          stop = true

        rescue Excon::Errors::Conflict
          stop = false
        rescue Excon::Errors::Forbidden
          stop = true
          puts "cannot create IP: kill the vm"
        end
      end
      
      kill(server.id) unless wait_for_ssh(public_ip)

      # return the identifier -> :provider :region :uuid
      REDIS.hdel("#{userid}:vi:#{vid}:transient", reqid)     
      {:location => zone, :server_id => server.id, :public_ip_address => public_ip, :ts_sshable => Time.now, :created => created, :cpid => @cpid}
    end
  
    def kill(id)
      s = @connection.servers.get(id)
      
      s.cloud_ips.each {|ip|
          mappedip = ip["id"]
          serverid = ip["server_id"]

          puts "unmapping ip #{mappedip} for: #{id}"
          begin 
            @connection.unmap_cloud_ip(mappedip)
          rescue Excon::Errors::Forbidden
          end
          begin 
            puts "destroying ip #{mappedip} for: #{id}"
            @connection.destroy_cloud_ip(mappedip)
          rescue Excon::Errors::Forbidden
          end
      }

      puts "killing bbox server: #{id}"
      begin 
        @connection.destroy_server(id)
      rescue Excon::Errors::Conflict
        puts "already dead"
      end      
    end
  
    def kill_by_ip(ip)
      puts "killing server by IP: #{ip}"
      @connection.servers.all.each {|s|
        next unless s.cloud_ips[0]
        next unless s.cloud_ips[0]["public_ip"]
            
        if s.cloud_ips[0]["public_ip"] == ip
          puts "deleting bbox vm: #{ip}"
          
          mappedip = s.cloud_ips[0]["id"]
          serverid = s.cloud_ips[0]["server_id"]

          @connection.destroy_server(serverid)
          @connection.unmap_cloud_ip(mappedip)
          @connection.destroy_cloud_ip(mappedip)
          break
        end
      }
    end
  
    def get_images
      res = []
      @connection.list_images.each {|img|
        if img["name"] =~ /^vi / 
          res.push({:image_id => img["id"], :name => img["name"]})
        end
      }
      res
    end
  
    def get_zones
      @connection.zones.collect {|z| z.handle}
    end
  
    # for now only lookup zones
    def locations
      {:id => @cpid, :zones => get_zones, :images => get_images}
    end
  end
end