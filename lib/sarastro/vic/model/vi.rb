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
# encapsulates state associated with a virtual Internet and manages
# creation / deletion of virtual internets
#
#
# OBSOLETE!!!

module VIC
  class VirtualInternet
    include CloudProviderController
    
    attr_reader :cps, :vid, :userid
      
    def initialize(userid, vid)
      @userid = userid
      @vid = vid      
    end

    def rebuild
      #   read all state from redis
      #   retrieve all state from the cloud providers
      #   compare local state with provider state
      #   remove instance id not present anymore
    end
  
    def topology
      {}    
    end
  
    def netapps
      [1,2,3]
    end
    
    def netapp(nid)
      case nid
      when 1
        {:location => "test", :status => "running"}
      when 2
        {:location => "eu", :status => "pending"}
      when 3
        {:location => "us", :status => "running"}
      end
    end
        
    # long-running query, should go on an event queue
    # 
    # if filter is empty, a netapp is created 
    def create_netapp(params, credentials)
    puts "wrong method"
  return nil
      @locations = filter_locations(@userid, params[:filter])

      return nil unless @locations # no locations found
      
      loc = choose_location(@locations)
      
      puts "creating netapp at: cpid #{loc[:cpid]}, zone #{loc[:zone]}" 
      
      cps[userid].create_netapp(loc.delete(:cpid), loc)
      
      # store the instance id in redis, so that it can be retrieved later   
      @location.merge({:nid => Random.new.rand(1..3)})
    end
    

    
    
    def add_consumer(stream)
      
    end
  end
end