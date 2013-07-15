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
# query cloud provider
#

module VIC
  class QueryCloudProviders 
    attr_reader :cps
       
    def initialize(settings, cps = nil)
      unless cps
        @cps = {}

        settings.each do |setting|        
          id = setting[:id]
          @cps[id] = case setting[:credentials][:provider]
            when "AWS" then EC2Provider.new setting, id
            when "Brightbox" then BBoxProvider.new setting, id
          end
        end      
      else
        @cps = cps # use already created cloud providers
      end
    end
    
    def wait_for(userid, vid, cpid, id, reqid)
      @cps[cpid].wait_for(userid, vid, id, reqid)
    end

    # Retrieve locations in parallel while calling blk on completion of each
    # query to a cloud provider. Request does block until all is finished.
    #
    # XXX: Doesn't work with em-synchrony, probably because of the EM.defer 
    #
    # @block[boolean] blocks until all queries executed
    # @&blk[proc] calls proc on each partial result
    def locations(&blk)
      cnt = @cps.size
      @locations = []  
      
      EM::Iterator.new(@cps, 100).each do |cp, iter|
        work = proc {
          cp[1].locations
        }
        done = proc {|result|          
          blk.call(result) if blk
          cnt-=1
          id = result.delete(:id)
          @locations.push({:cpid => id, :locations => result})
          iter.next
        }
        EM.defer(work, done)        
      end
            
      timer = EM::PeriodicTimer.new(1) { 
        unless cnt > 0
          blk.call(nil)  
          timer.cancel
        end
      } if blk
  
      while cnt > 0 do; Thread.pass; end 
      @locations
    end 
     
     # Create netapp. Calls cloud specific method.
     #
     # @param [Hash] parameters Credentials and parameters to allocate a 
     #   netapp
     def create_netapp(userid, vid, reqid, parameters)
       @cps[parameters.delete(:cpid)].create_netapp(userid, vid, reqid, parameters)
     end
    
     def kill(cpid, id)
       @cps[cpid].kill(id) if @cps[cpid]
     end
    
     # @param [Array] locations List of locations from a previous query
     def cached_locations(locations)
       @locations = locations
     end
     
     def cached_locations?
       @locations ? true : false
     end
     
     # Return locations using key/values pairs to select. It assumes that 
     # locations are already provided to avoid blocking and will return nil
     # if no locations are loaded.
     # 
     # @param [Hash] filter Selection criteria
     def filter_locations(filter)
       filter = {} if filter.nil?
       return nil unless @locations
       res = []
       
       @locations.each_with_index {|obj,index|
         id = obj[:cpid]
         val = obj[:locations].clone
         tmp = filter.map {|key, sel|
           if val[key]
         		 case val[key]
         		 when String
         		   val[key] if val[key].include?(sel)
         		 when Array
         		   m = val[key].find_all {|e| e.include? sel}
         		   val[key] = m unless m.nil? || m.empty?
         		   m
         		 else
                nil
         		 end
            end
       		}
          if tmp.find_all {|e| e.nil? || e.empty?}.empty?
            res.push({:cpid => id}.merge(val))
          end
      	 }
       res
     end

     # Chooses a region from a given cloud provider list
     # 
     # @param [Array] locs List of cloud providers     
     def choose_region(locs)
       return {:cpid => locs.sample[:cpid]} if locs
       nil
     end
     
     # Chooses a zone from a given cloud provider list
     # 
     # @param [Array] locs List of cloud providers
     def choose_zone(locs)      
       cp = locs.sample
       puts " cp: #{cp}"
       zone = cp[:zones][0]

       if (zones = cp[:zones]).size > 1
          zone = zones.sample
       end

       return {:cpid => cp[:cpid], :zone => zone}
     end
  end
end