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
# Maintains a reference to all cloud providers, provides methods to manage
# cloud provider credentials, and to query cloud provider locations and state.
# 
# user:cp:cpid -> {provider_credential1, provider_credential2}
#

module VIC
  module CloudProviderController   
    # shortcut 
    def cps
      CloudProviderStore.instance
    end

    def add_cloud_provider(userid, data, replace = false)
      # XXX: should only flush the cloud provider informations...
      # XXX: something with keys -> del all values...
      REDIS.flushdb if replace
                  
      JSON.parse(data, :symbolize_names => true)[:cloud_providers].each do |cp|
        cpid = REDIS.incr("#{userid}:cp:id")

        res = REDIS.multi do
          REDIS.set("#{userid}:cp:#{cpid}:settings", cp.to_json)
          REDIS.sadd("#{userid}:cp:all", "#{userid}:cp:#{cpid}:settings")
          REDIS.set("#{userid}:cp:all:ts", Time.now.to_i)          
        end

        # XXX: should do a roll-back here, because some could have succeeded
        return false unless res[0] == "OK" 
      end

      true
    end

    def del_cloud_provider(userid, cpid)
      res = REDIS.multi do
        REDIS.del("#{userid}:cp:#{cpid}:settings")
        REDIS.srem("#{userid}:cp:all", "#{userid}:cp:#{cpid}:settings")
        REDIS.set("#{userid}:cp:all:ts", Time.now.to_i)
      end
    end

    def cloud_provider_credentials(userid)
      cpids = REDIS.smembers("#{userid}:cp:all")
      res = REDIS.mget *cpids unless cpids.nil? || cpids.empty?
      res = res.each_with_index.map {|e, i| {:id => get_id(cpids[i])}.merge(JSON.parse(e, :symbolize_names => true))} unless res.nil?

      res.nil? || res.empty? ? [] : res
    end

    def cloud_provider_credential(userid, cpid)
      res = REDIS.get("#{userid}:cp:#{cpid}:settings") 
      res = JSON.parse(res, :symbolize_names => true) unless res.nil? || res.empty?

      res.nil? || res.empty? ? "" : res
    end

    # XXX: multiple queries will spawn multiple parallel requests ->
    # We only want to query locations when credentials change.
    #
    # So, do querying in the background and only after an add or delete.
    # location requests while queries are running should result in nil
    #
    # What to do with multiple add and deletes? It seems that explicit calling
    # is better..
    def update_locations(userid, force = false, &blk)
      loc_ts = REDIS.get("#{userid}:cp:locations:ts")
      cp_ts = REDIS.get("#{userid}:cp:all:ts")

      if force || loc_ts.nil? || cp_ts.nil? || loc_ts.empty? || cp_ts.empty? || cp_ts.to_i - loc_ts.to_i > 0
        self.cps[userid] = QueryCloudProviders.new(cloud_provider_credentials(userid)) 
        
        res = self.cps[userid].locations(&blk)
        unless res.empty?
          REDIS.multi do 
            REDIS.set("#{userid}:cp:locations:ts", Time.now.to_i)      
            REDIS.set("#{userid}:cp:locations", res.to_json)
          end
        end
      else
        res = REDIS.get("#{userid}:cp:locations")
        res = JSON.parse(res, :symbolize_names => true) 
        unless self.cps[userid]
          self.cps[userid] = QueryCloudProviders.new(cloud_provider_credentials(userid)) 
          self.cps[userid].cached_locations(res)
        end
      end

      res
    end

    # This will block if cloud providers were updated!
    def filter_locations(userid, filter)
      update_locations(userid)
      
      return self.cps[userid].filter_locations(filter) 
    end

    def get_id(str)
      str.split(":")[2]
    end
  end  
end