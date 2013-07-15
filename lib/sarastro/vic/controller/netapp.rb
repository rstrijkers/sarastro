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
#   
#

module VIC
  module NetappController
    include CloudProviderController
    include HMACAuth::Helpers
        
    # Assumes that it is started BEFORE the main loop, i.e. conclicts with
    # run time waiting on vms.
    # 
    # makes sure that any netapps that were started before crash will be 
    # recovered
    def check_integrity(userid, vid, rid)
      update_locations(userid) # populate cps

      # transient, in process of creating, but no IP and no status written back
      # active: store of start of the job
      data = REDIS.hgetall("#{userid}:vi:#{vid}:transient")
      data.map {|d|
        reqid = d[0]
        info = JSON.parse(d[1], :symbolize_names => true)
        NetappApp.enqueue("wait_for_vm", userid, vid, info[:cpid], info[:server_id], reqid)
      }
    end
    
    def wait_for_vm(userid, *params)
      puts "params: #{params}"
      puts "Starting wait for vm: vid #{params[1]}, server id #{params[3]}, cp #{params[0]}"
      puts "cloud provider: #{cps[userid]}"
      params.pop
      puts "params #{params}"
      
      cps[userid].wait_for(*([userid] | params))
    end
    
    def get_netapp(nid)      
      j(REDIS.hget("queue:netapp:data", nid))
    end

    def get_link_by_tuple(userid, vid, tuple)
      lid = REDIS.hget("#{userid}:vi:#{vid}:netapp:#{tuple[0]}:links", "#{tuple[0]}:#{tuple[1]}")
      return nil unless lid
      REDIS.hget("queue:netapp:data", lid)      
    end

    # the link should be in both client and server, only look at the server
    def get_link(userid, vid, nid, lid)
      l = REDIS.hget("#{userid}:vi:#{vid}:netapp:#{nid}:links", lid)
      return get_netapp(l) if l
      nil
    end
    
    # XXX: If the netapps set isn't consistent with the data hash, then we'll get
    # nils.... shouldn't happen, but we don't have a complete implementation..
    def get_netapps(userid, vid)
      get_property("netapps", userid, vid)
    end
    
    def get_links(userid, vid)      
      get_property("links", userid, vid)
    end
    
    def get_property(property, userid, vid)
      # Get all the netapps with virtual internet id vid
      nids = REDIS.smembers("#{userid}:vi:#{vid}:#{property}")
      puts "#{property}: #{nids}"
      return nil if nids.empty?

      # XXX: got a bus error here once
      # XXX: cannot reproduce with empty values though...
      res = REDIS.hmget("queue:netapp:data", *nids) 
      return nil if res.empty? || res.nil?
      res.map {|e| j e }
    end    
    
    def run_on_all_netapps(userid, vid, name, params, rid)
      return nil unless nas = get_netapps(userid, vid)
      
      nas.each {|na|
        if params[:multi]
          puts "found multi"
          p = params[:multi][na[:requestid].to_s.to_sym]
          puts "setting params: #{p}"
        else
          p = params
        end

        # XXX: untested, don't do anything if the netapp has no public ip address
        unless na[:output]
          unless na[:output][:public_ip_address]
            next
          end
        end
            
        puts "run on: #{na[:output][:public_ip_address]} with params #{p.inspect}"
        NetappApp.enqueue("run_on_netapp", userid, vid, na, name, p.merge({:nid => na[:requestid]}))
      }
      
      NetappApp.dispatch_event("run_on_all_netapp:#{rid}", "")
    end

    def run_on_netapp(userid, vid, netappdata, name, params, rid)
      params = {} unless params  
      res = NetappRunner.run(userid, vid, netappdata, name, params.merge({:hmac => get_hmac_credentials(userid, vid), :nid => netappdata[:requestid]}))
      
      NetappApp.dispatch_event("run_on_netapp:#{netappdata[:requestid]}", "{name:\"#{name}\", result\":#{res}\"}")
      
      res
    end

    # run a local script on the virtual internet
    def run_script(userid, vid, name, args, rid)
      # run the script with the arguments
      puts "running local script for virtual internet: #{userid}:#{vid}:#{name}" 
      res = NetappRunner.run_local(args)
      
      # raise event with results
      NetappApp.dispatch_event("run_script:#{rid}", res)
      
      res      
    end
    
    # There are many options that need consideration when creating links:
    # Are there any optimizations save tunnels?
    #   - query network as a service providers
    #   - fiber optic paths
    #   - bridges 
    #   - other application-specific solutions
    #
    # arguments:
    #   {src => "nid", dst => "nid"}
    def create_link(userid, vid, tuple, reqid)
      started = Time.now
      # block until both netapps have public ip addresses
        # if a netapp disappears, cancel link creation
      src = nil
      dst = nil
      
      # start wait loop
      loop do
        src = get_netapp(tuple[:src])
        dst = get_netapp(tuple[:dst])
    
        if src.nil? || dst.nil?
          return {:status => false, :msg => "one of the netapps doesn't exist: #{tuple.inspect}"}
        end
        
        if tuple[:src] == tuple[:dst]
          return {:status => false, :msg => "do not allow self links: #{tuple.inspect}"}
        end
        
        # both are finished, check if status is done      
        if src[:status] == "done" && dst[:status] == "done"
          break
        end
        
        if src[:status] == "failed" || dst[:status] == "failed"
          return {:status => false, :msg => "one of the netapps failed: #{tuple.inspect}"}
        end 
                
        Thread.pass       
        # XXX: put a timeout here to bail out when things seem to go wrong.
      end
      
      # XXX: final check: add no double links (unless we can distinguish those better)
      server, client = order_link([src,dst])
      a = REDIS.hget("#{userid}:vi:#{vid}:netapp:#{server[:requestid]}:links", "#{server[:requestid]}:#{client[:requestid]}")
      b = REDIS.hget("#{userid}:vi:#{vid}:netapp:#{client[:requestid]}:links", "#{server[:requestid]}:#{client[:requestid]}")                  
      
      res = nil
      # if everything is ok, actually create the link      
      if a.nil? && b.nil?
        res = create_link_post(userid, vid, {:link => [src, dst]}, reqid) 
      else
        puts "not creating double link: #{server[:requestid]} - #{client[:requestid]}!"
      end
      
      # creating failed
      # XXX: untested
      if(res == nil)
        puts "failed to create link!! running roll_back!"
        NetappApp.enqueue("kill_link", userid, vid, "#{src}:#{dst}")
      end
      
      NetappApp.dispatch_event("create_link:#{reqid}", res)
      
      res
    end

    # takes array of two netapps
    # links are ordered, so that the edges become undirected
    def order_link(link)
      return unless link
      link.sort {|x,y| 
        return nil unless x && y;  x[:requestid] <=> y[:requestid]
      }
    end

    # XXX: assumes that the names of the netapps are consistent, i.e. public
    # ips or dns name, not both mixed to refer to the same netapp
    # XXX: DOES --NOT!-- check if multiple paths are created! From the vtun
    # perspective it is totally valid to create more tunnels between two 
    # endpoi
    def create_link_post(userid, vid, params, reqid)
      # don't make reverse connections (src->dst) == (dst->src), sort:
      server, client = order_link(params[:link])

      # already add the link to the db. rollback on error
      REDIS.multi do
        REDIS.sadd("#{userid}:vi:#{vid}:links", reqid)
        REDIS.hset("#{userid}:vi:#{vid}:netapp:#{server[:requestid]}:links", "#{server[:requestid]}:#{client[:requestid]}", reqid)
        REDIS.hset("#{userid}:vi:#{vid}:netapp:#{client[:requestid]}:links", "#{server[:requestid]}:#{client[:requestid]}", reqid)
      end

      timeout = 30 # if requests take longer something is broken
      server_ip = server[:output][:public_ip_address] 
      client_ip = client[:output][:public_ip_address]
      hmac = get_hmac_credentials(userid, vid)
    
      # create server      
      server_data = j(do_request(server_ip, :post, "link/server", hmac))
      if server_data
        if server_data[:port].to_i < 0
          # failed
          return nil
        end
      else
        return nil
      end
        
      client_data = j(do_request(client_ip, :post, "link/client", hmac, {:port => server_data[:port], :dest => server_ip}))
      # rollback if client fails, kill server
      unless client_data
        do_request(server_ip, :delete, "link/server/#{server_data[:port]}", hmac)
      
        REDIS.multi do
          REDIS.srem("#{userid}:vi:#{vid}:links", reqid)
          REDIS.hdel("#{userid}:vi:#{vid}:netapp:#{server[:requestid]}:links", "#{server[:requestid]}:#{client[:requestid]}")
          REDIS.hdel("#{userid}:vi:#{vid}:netapp:#{client[:requestid]}:links", "#{server[:requestid]}:#{client[:requestid]}")
        end
      
        return nil
      end
      
      {:server => server[:requestid], :client => client[:requestid], :server_data => server_data, :client_data => client_data}
    end
    
    # generated at creation of a virtual internet
    def get_hmac_credentials(userid, vid)
      j(REDIS.get("#{userid}:vi:#{vid}:hmac"))
    end
  
    # convenience method for doing a blocking http post with hmac
    #
    # should retry if sarastro_netapp is booting while the request is made
    def do_request(server_ip, method, path, hmac, params = {})
      header, url = hmac_query(server_ip, method, path, hmac, params)      

      # do query - blocking
      puts "calling url: #{method} #{url}"
      request = Typhoeus::Request.new(url,
        :method        => method, 
        :headers       => header,
        :params        => params.merge({:id => hmac[:id]}))           
        
      Thread.current[:hydra] ||= Typhoeus::Hydra.new(:max_concurrency => 100)
      hydra = Thread.current[:hydra]
      hydra.queue(request)
      hydra.run
      
      request.response.body
    end
    
    # Blocking method to create netapp. Waits until netapp is sshable.
    #
    # XXX: should provide timeout to indicate failure... what is a good 
    #   time-out? creation can take up to 5 minutes...
    # 
    #  required: cloud provider 
    #    optional: filter
    #      -> cloud provider + optional availability zone
    #      -> no filter: select random cloud provider
    #    -> cloud provider + optional availability zone
    #      -> credentials
    #      -> region
    #
    #  required: netapp name
    #    -> imageid
    #
    # parameters:
    # {
    #   :name => "",
    #   :filter => {:region => "eu", :zone => "west"}
    # }
    def create_netapp(userid, vid, parameters, reqid)
      return nil unless cps[userid]
      cp = filter_locations(userid, parameters[:filter]) # this may block 

      # cloud provider
      unless parameters[:cpid]
        if parameters[:filter] && parameters[:filter][:zones]
          parameters.delete(:filter)
          location = cps[userid].choose_zone(cp) # {:cpid => x, :zone =>x}
          return nil unless location

          parameters[:zone] = location[:zone]
        else # XXX: cloud providers are bound to regions
          location = cps[userid].choose_region(cp) # {:cpid => x}          
          return nil unless location
        end

        parameters[:cpid] = location[:cpid]
      end
      
      # get vi image for the cloud provider
      selected_cp = cp[cp.index {|e| e[:cpid] == parameters[:cpid]}][:images]
      if parameters[:name]
        imageid = selected_cp.index {|v| break v[:image_id] if v[:name] =~ /#{parameters[:name]}/ }
      else # then just grab the first matching the 'vi' prefix
        imageid = selected_cp.index {|v| break v[:image_id] if v[:name] =~ /^vi/ }
      end      
      return nil unless imageid
      parameters[:imageid] = imageid

      # make this request for a vm a member of our virtual internet
      REDIS.sadd("#{userid}:vi:#{vid}:netapps", reqid)

      # returns instanceid + public ip address, set those in the data struct
      res = cps[userid].create_netapp(userid, vid, reqid, parameters)
      
      # raise event that vm is running
      NetappApp.dispatch_event("create_ne:#{reqid}", res ? res.to_json : "")
      
      res
    end 

    def kill_netapp(userid, vid, nid, rid)
      return nil unless cps[userid]
      
      na = get_netapp(nid)
      return nil unless na
      
      if na[:output]
        if na[:output][:server_id]
          puts "netapp #{na.inspect}"
          puts "killing netapp (#{nid}) in vi #{vid}: #{na[:output][:server_id]}"
          
          # delete the actual vm      
          cps[userid].kill(na[:output][:cpid], na[:output][:server_id])
        end
      else
        puts "netapp is busy creating, checking transient store for #{nid}..."
        
        # if the netapp is busy creating, the data structures aren't set yet...
        inf = j(REDIS.hget("#{userid}:vi:#{vid}:transient", nid))
        puts "transient: #{inf.inspect}"
        
        cps[userid].kill(inf[:cpid], inf[:server_id]) if inf
        # XXX: when the server is killed, the provider will remove it...   
      end

      # remove entries from data structures
      REDIS.multi do
        REDIS.srem("#{userid}:vi:#{vid}:netapps", nid)
       # REDIS.hdel("queue:netapp:data", nid) # we like to keep this data for statistics
      end
      
      # remove the entries with links to this netapp
      kill_links(userid, vid, nid)

      # raise event
      NetappApp.dispatch_event("kill_ne:#{rid}", "{}")

      nil
    end

    def kill_links(userid, vid, nid)
      links = REDIS.hgetall("#{userid}:vi:#{vid}:netapp:#{nid}:links")
      
      links.each {|k,v|
        puts "link: #{k} -> #{v}" 
        REDIS.multi do
          res = j(REDIS.hget("queue:netapp:data", v))
          if res
            REDIS.hdel("#{userid}:vi:#{vid}:netapp:#{res[:output][:server]}:links", k)
            REDIS.hdel("#{userid}:vi:#{vid}:netapp:#{res[:output][:client]}:links", k)        
          end
          REDIS.srem("#{userid}:vi:#{vid}:links", v)
        end
      }
      REDIS.del("#{userid}:vi:#{vid}:netapp:#{nid}:links")      
    end

    def kill_link(userid, vid, tuple = "", reqid)
      nids = tuple.split(":")
      return unless nids.size == 2
      
      server, client = order_link([get_netapp(nids[0]), get_netapp(nids[1])])

      # it could be that the link exists, but that the nodes disappeared.
      # we have to go through the list of links and check if we find the
      # links..
      unless server && client
        server, client = nids.sort
        links = get_links(userid, vid)
        return nil unless links
        links.each {|lid|
          if lid[:output][:server].to_i == server.to_i
            if lid[:output][:client].to_i == client.to_i
              # remove the link and exit
              REDIS.srem("#{userid}:vi:#{vid}:links", lid[:requestid])
              REDIS.hdel("queue:netapp:data", lid[:requestid])                
              return nil      
            end
          end
        }     
        
        return nil     
      end
      
      server_ip = server[:output][:public_ip_address] 
      client_ip = client[:output][:public_ip_address]
      hmac = get_hmac_credentials(userid, vid)
      lid = "#{server[:requestid]}:#{client[:requestid]}"
      link = get_link(userid, vid, server[:requestid], lid)
      puts "link: #{link.inspect}"
      
      if link      
        # delete client -> dest, port
        do_request(client_ip, :delete, "link/client/#{link[:output][:client_data][:port]}/#{server_ip}", hmac)
      
        # delete server -> port
        do_request(server_ip, :delete, "link/server/#{link[:output][:server_data][:port]}", hmac)

        REDIS.multi do
          REDIS.srem("#{userid}:vi:#{vid}:links", link[:requestid])
          REDIS.hdel("#{userid}:vi:#{vid}:netapp:#{server[:requestid]}:links", lid)
          REDIS.hdel("#{userid}:vi:#{vid}:netapp:#{client[:requestid]}:links", lid)
          REDIS.hdel("queue:netapp:data", lid)
        end
      end
      
      # raise event
      NetappApp.dispatch_event("kill_link:#{lid}", link.to_json)      
    end
    
    # kill all netapps associated with the virtual internet id
    def killall_netapps(userid, vid)
      puts "killing all netapps for #{userid}:vid"

      nas = get_netapps(userid,vid)
      if nas
        nas.each {|na| 
          next if na.nil? || na.empty?
          NetappApp.enqueue("kill_netapp", userid, vid, na[:requestid])
        }
      end
      REDIS.del("#{userid}:vi:#{vid}:netapps")      
    end
    
    # kill all the virtual machines. this is a last resort in cases of 
    # bugs...
    def killall(userid)
      # for each cloud provider 
        # for each zone
          # for each vm
            # kill vm
    end
    
    def j(str)
      begin
        if str                
          return JSON.parse(str, :symbolize_names => true)
        end
      rescue
        return nil
      end
    end
  end
end