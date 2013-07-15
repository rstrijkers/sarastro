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
# Creates and manages Virtual Internets. 
#

module VIC  
  module VirtualInternetController
    include NetappController
    
    # Maintain state in the class of the object, because an instance of 
    # the app is made every request
    def self.included(base)
      class << base; attr_accessor :vic_vi; end
    end
    
    # Also add instance methods
    def vi
      self.class.vic_vi = {} unless self.class.vic_vi
      self.class.vic_vi
    end
    def vi=(val); self.class.vic_vi=val; end
    
    # A new virtual internet is merely a process id to which netapps
    # can be attached
    def new_virtual_internet(userid)
      vid = REDIS.incr("#{userid}:vi:id")
      REDIS.sadd("#{userid}:vi", vid)
      REDIS.set("#{userid}:vi:#{vid}:hmac", {:id => UUID.create_uuid, :key => UUID.create_uuid + UUID.create_uuid}.to_json)
      vid
    end
     
    def get_virtual_internets(userid)
      vis = REDIS.smembers("#{userid}:vi")
      vis.map! {|vi|
        {:vid => vi, :hmac => get_hmac_credentials(userid, vi)}
      }
    end

    # XXX: incomplete...
    def get_virtual_internet(userid, vid)
      REDIS.smembers("#{userid}:vi")      
    end
    
    # blocking process: use in job queue
    def del_virtual_internet(userid, vid)
      # first kill all netapps
      killall_netapps(userid, vid)
      
      # then remove our references      
      REDIS.srem("#{userid}:vi", vid)
      REDIS.del("#{userid}:vi:#{vid}:hmac")
    end

    # only necessary at startup: if the sarastro crashed while servers where
    # creating, we must reassociate the reqid to the server status.
    # 
    # don't use this at runtime, because at any time it is normal to have vms
    # in transient.
    def check_virtual_internet(userid, vid)
      # XXX: !
    end

    def rebuild_virtual_internet(userid, vid)
      new_virtual_internet(userid, vid) unless self.vi[userid]
      self.vi[userid][vid].rebuild
    end

    def next_resource_id(userid)
      REDIS.incr("#{userid}:vi:id")
    end
  end
end