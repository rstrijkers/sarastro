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
# EC2 Compute Facility
#
# Abstracts creation and management of netapps. 
#
# 
# XXX: Add ssh key pair management! -> now assumes user rudolf with 
#      keypair provisioned

module VIC
  class EC2Provider
    # include SetupHelpers
    
    attr_accessor :region, :compute
    attr_reader :provider
  
    def initialize(settings, cpid)
      @cpid = cpid
      @provider = "AWS"
      @parameters = settings[:parameters]
      @credentials = settings[:credentials]
      @connection = Fog::Compute.new(@credentials)
    end
    
    # long-running query
    # 
    # Creates a netapp at a specific region using default behavior when no
    # parameter is given:
    #   image-id: lookup image id associated with virtual internet
    #   flavor: always the smallest
    #   location: region of connection, random zone
    #
    # can we associate an image id with a name? That makes life easier over
    # cloud providers...
    # 
    # transform :zones into the specific id...
    def create_netapp(userid, vid, reqid, params)
      awsparams = {}
      tmp = params.delete(:zone)
      awsparams[:availability_zone] = tmp if tmp
      awsparams[:image_id] = params.delete(:imageid)
      awsparams[:flavor_id] = 'm1.small'
#      awsparams[:flavor_id] = 't1.micro'
      
      # we have to wait anyway, so we just wait until the machine becomes
      # sshable
      puts "creating #{@provider} vm with parameters #{awsparams}"
      
      # create vm
      server = @connection.servers.create(awsparams)
      
      # if the jobs dies after the create command, but before the vm is up,
      # we can't match the vm to the request id anymore...       
      # So, store the instance id's in a temporary storage and have another
      # function regularly check consistency 
      REDIS.hset("#{userid}:vi:#{vid}:transient", reqid, {:server_id => server.id, :cpid => @cpid}.to_json)
      
      # wait for public ip address
      server.wait_for { puts "waiting for ec2 vm (vid: #{vid} id: #{id})..."; ready? || state == 'terminated'}
      created = Time.now
      
      # wait for ssh to come up and make sure it's dead if ssh fails
      # XXX: apparently this crashes everytime a time-out occurs..., don't then...
      # kill(server.id) unless 
      wait_for_ssh(server.public_ip_address)
      
      # remove the entry once we have an ip address, the vm is up and will be 
      # associated to the node.
      REDIS.hdel("#{userid}:vi:#{vid}:transient", reqid)      
      {:location => awsparams[:availability_zone], :server_id => server.id, :public_ip_address => server.public_ip_address, :ts_sshable => Time.now, :created => created, :cpid => @cpid}
    end

    # XXX: refactor, ec2 & bbox code exactly the same!
    def wait_for(userid, vid, id, reqid)
      if s = @connection.servers.get(id)
        # wait for public ip address
        s.wait_for { 
          puts "waiting for ec2 vm (vid: #{vid} id: #{id})..." 

          ready? || state == 'terminated' || REDIS.sismember("#{userid}:vi:#{vid}:netapps", reqid)}
        created = Time.now

        # rewrite the data
        append = {:server_id => id, :public_ip_address => s.public_ip_address, :ts_sshable => Time.now, :created => created, :cpid => @cpid}      
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
    end

    # XXX: same as bbox
    #
    #
    # XXX: synchronize with Bbox. Even better merge the code!!!!!
    def wait_for_ssh(ip)
      username = "rudolf"
      
      return false if ip == nil
      return false if ip.size < 7
      
      # XXX: from Fog: wait for aws to be ready
      begin
        Timeout::timeout(600) do
          begin
            Timeout::timeout(8) do
              Fog::SSH.new(ip, username, {:timeout => 4}).run('pwd')
              return true
            end
          rescue Errno::ECONNREFUSED
            sleep(2)
            puts "#{self.class}: Connection refused #{ip}"          
            retry
          rescue Net::SSH::AuthenticationFailed, Timeout::Error
            retry
          rescue Net::SSH::Disconnect
            puts "#{self.class}: VM probably gone.... stopping."
          end        
        end
      rescue
        puts "#{self.class}: Timeout > 600 seconds"
      end
      
      false
    end

    # XXX: refactor, ec2 & bbox code exactly the same!
    def kill(id)
      # may crash... but why?
      puts "killing vm with id: #{id}" 
      s = @connection.servers.get(id)
      s.destroy if s
#      @connection.servers.all.each {|s|
#        if s.public_ip_address == id
#          puts "deleting ec2 vm: #{ip}"
#          s.destroy
#          break
#        end
#      }
    end

    # return all images with "vi " prefix
    def get_images
      res = []
      @connection.describe_images({
        "Owner" => @parameters[:owner]
      }).body["imagesSet"].each {|is| 
        if is["name"] =~ /^vi / 
          res.push({:image_id => is["imageId"], :name => is["name"]}) 
        end
      } 
      res   
    end
  
    def get_zones
      @connection.describe_availability_zones.body["availabilityZoneInfo"].collect {|z| z["zoneName"]}
    end
  
    def locations
      begin
        {
          :id => @cpid, 
          :region => @credentials[:region], 
          :zones => get_zones, 
          :images => get_images
        }
      rescue Fog::Compute::AWS::Error => error
        {:id => @cpid, :status => error}
      end
    end
  end
end