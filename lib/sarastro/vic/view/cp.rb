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

module VIC
  class CloudProviderApp < Sinatra::Base
    include CloudProviderController
    #register Sinatra::Async
    register OpenIDAuth

    use Rack::MethodOverride  # allow post to simulate put / delete

    # ---- API calls ----
    before '/api/cp*' do
      require_openid_authentication
    
      unless session[:user_attributes].nil? 
        @userid = session[:user_attributes][:email] 
      else
        @userid = params[:userid] # on localhost we allow login
      end
    end

    get '/api/cp' do
      [200, {}, cloud_provider_credentials(@userid).to_json]
    end

    # XXX: could also make an asynchronous one with a resource id...
    # XXX: we cache the results anyway...
    #
    # Keeps a stream open while executing a long-running query.
    get '/api/cp/locations' do
      force = false
      force = true if params[:new] == "new"
    
      # XXX: refactor, this code is the same as for /cp/locations except the
      # force parameter....
      stream(:keep_open) do |out|
        callback = false
        # prevent the socket to time-out in long running events.
        EventMachine::PeriodicTimer.new(20) { out << "\0" }
      
        done = update_locations(@userid,force) {|b|
          if b
            out << "partial_result: #{b.to_json}\n"
          else
            out.close
            end
          callback = true
        }
      
        unless callback
          out << "cached_result: #{done.to_json}\n" 
          out.close
        end
      end
    end

    # XXX: finish the filter
    # 
    # Because filter depends on the location query, this may also block. 
    # Blocking can be prevented by updating the cache with forcing a location
    # search.
    # 
    get '/api/cp/filter' do
      # make sure that only these parameters go through the filter
      params.delete_if {|k,v| 
        !(k == "region" || k == "zones")
      }
    
      filter = params.each_with_object({}){|(k,v), h| h[k.to_sym] = v}

      # If cache is not filled, this call will block and potentially time-out,
      # so return nil here then...
      unless cps[@userid]
        [200, {}, "No locations fetched"]
      else
        [200, {}, filter_locations(@userid, filter).to_json]
      end
    end

    get '/api/cp/:cpid' do      
      [200, {}, cloud_provider_credential(@userid, params[:cpid]).to_json]
    end    
      
    # ---- UI calls ----
    before '/cp*' do
      require_openid_authentication
    
      @userid = session[:user_attributes][:email]  
      @user = session[:user_attributes] 
    end
  
    get '/cp' do
      erb :"cp/provider", :locals => {
        :credentials => cloud_provider_credentials(@userid), 
        :user => @user
      }
    end

    # XXX: ui, but erb and streams won't work out of the box with sinatra, 
    # i.e. we must do it ourselves
    get '/cp/locations' do
      stream(:keep_open) do |out|
        callback = false
        # prevent the socket to time-out in long running events.
        EventMachine::PeriodicTimer.new(20) { out << "\0" }
      
        done = update_locations(@userid) {|b|
          if b
            out << "partial_result: #{b.to_json}\n"
          else
            out.close
          end
          callback = true
        }
      
        unless callback
          out << "cached_result: #{done.to_json}\n" 
          out.close
        end
      end
    end

    # Register a cloud provider
    #
    # { "cloud_providers" : 
    #   [
    #     {
    #       "provider" : "aws",
    #       "access_key" : "oaeuaeouaoeuaii",
    #       "secret" : "20aeohucrau"
    #       "region" : "us-west-1"
    #     },
    #     {
    #       "provider" : "bbox",
    #       "client-id" : "clienteuoheai",
    #       "secret" : "qhaoeuaeou"
    #     }
    #   ]
    # }
    # XXX: refactor... 
    post '/cp' do   
      # accept raw json
      if params[:json]
        success = add_cloud_provider @userid, params[:json]
      end
    
      # accept file with json
      if params[:file]
        success = add_cloud_provider @userid, params[:file][:tempfile].read, true
      end
    
      if success 
        [201, {}, ""]      
      else
        [202, {}, "Error: Could not create cloud provider credential data."]         
      end
    end

    # deleting credentials won't delete the current connections and running 
    # netapps
    delete '/cp/:cpid' do
      del_cloud_provider @userid, params[:cpid]
                
      [204, {}, ""]
    end
  end  
end