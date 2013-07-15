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
# XXX: cleanup, finish API calls...

module VIC
  class VirtualInternetControllerApp < Sinatra::Base
    include VirtualInternetController
    
    register OpenIDAuth
    #register Sinatra::Async
    
    use Rack::MethodOverride  # allow post to simulate put / delete

    enable :sessions
    use Rack::Session::Cookie, :secret => "MY_SECRET"    

#
# ---- API calls ----
#
    before '/api/vi*' do
      require_openid_authentication
      unless session[:user_attributes].nil? 
        @userid = session[:user_attributes][:email] 
      else
        puts "is nil"
        @userid = params[:userid] # on localhost we allow login
      end
    end
    
    get '/api/vi' do
      
      [200, {}, s(get_virtual_internets(@userid))]
    end
    
    get '/api/vi/:vid' do
      # XXX: should be done in the background. The most recent state must
      #   always be present in cache.
      # rebuild virtual internet if state might be inconsistent have changed...
      # rebuild_virtual_internet(@userid, params[:vid])
      
      [200, {}, vi[@userid][params[:vid]].class.to_json]
    end
    
    # format the topology of the vi. Always get this from cache. If a netapp
    # changes status without informing vic, it can only be detected by 
    # polling. So, there is need for some monitoring process anyway, which
    # is responsible for maintaining consistency between db and the real
    # situation...
    #
    # XXX: retrieve the virtual internet topology. The most recent version 
    #   must always be present in cache.
    get '/api/vi/:vid/topology' do
      [200, {}, vi[@userid][params[:vid]].topology.to_json]
    end
    
    post '/api/vi' do
      vid = new_virtual_internet(@userid)
      
      [201, {"Location" => "http://localhost:4567/vi/#{vid}"}, ""]
    end  

    # Create netapp and if zone filter specified, result action:
    #   - no zone: return
    #   - 1 zone: choose zone
    #   - multiple zones: choose random
    #
    # If no filter is specified, creates netapp at a random region and 
    # random zone.        
    # 
    # takes a callback url on finish. Internally, we must have an observer for
    # it... (the virtual internet controller..., or if none, the user is 
    # responsible...)
    post '/api/vi/:vid/netapp' do
      # asynchronous, return a request id to query resource
    end
         
    delete '/api/vi/:vid' do
      del_virtual_internet(@userid, params[:vid])
      [204, {}, ""]      
    end
    
#
# ---- UI calls ----
#
    before '/vi*' do
      require_openid_authentication
      @userid = session[:user_attributes][:email]
    end

    # vi interface
    #   -> make netapps
    #   -> create topologies
    #   -> make generators
    #   -> display infrastructure
    #
    # Could be a stream event to send continuous updates about
    # state, i.e. install a callback that subscribes to a number of events
    #
    get '/vi/:vid' do
      # XXX: can be better implemented using 'pass'
      return [200, {}, NetappRunner.list.to_json] if params[:vid] == "apps"
      
      erb :"vi/ui", :locals => {
        :user => session[:user_attributes],
        :vid => params[:vid]
      }
    end
          
    get '/vi' do
      erb :"vi/list", :locals => {
        :user => session[:user_attributes],
        :vis => get_virtual_internets(@userid)        
      }
    end

    get '/vi/:vid/controller' do
      erb :"vi/controller", :locals => {
        :user => session[:user_attributes],
        :vid => params[:vid]
      }
    end    
  
    # check integrity, for now user initiated, should be automatic on startup
    get '/vi/:vid/integrity' do
      NetappApp.enqueue("check_integrity", @userid, params[:vid])

      redirect "/vi/#{params[:vid]}"
    end    
    
    # subscribe to event with this virtual internet usings streams.
    # we could also use pubsubhubbub or some other event notification system,
    # but then we'd be polling again. Better to have some channels open.
    get '/vi/:vid/feed', provides: 'text/event-stream' do
      stream(:keep_open) do |out|                        
        # extend object to accept observer update 
        keep_alive = EM::PeriodicTimer.new(20) { out << "data: pong!\n\n" }

        # update will be called if NetappApp notifies: 
        #    changed
        #    notify_observers(result)
        # XXX: to be tested
        class <<out
          def update(result)
            # filter on results
            self << "data: #{result.to_json}\n\n"
          end
        end         
#         NetappApp.add_observer(out, {:userid => @userid, :vid => @vid})
        NetappApp.add_observer(out)

        out.callback {
          NetappApp.delete_observer(out)
          keep_alive.cancel
        }
        out.errback {
          NetappApp.delete_observer(out)
          keep_alive.cancel
        }
     end
    end
                
    # create virtual internet
    # 
    # post request
    #  Location: callback url
    # 
    #  body: parameters in json
    post '/vi' do
      vid = new_virtual_internet(@userid)
      
      # should also post an access key and secret
      
      # the access key + secret will be uploaded to the netapp once it's up 
      # and used for communication between netapp instances.
      
      # If no key / secret is given, we'll generate one based on the user
      # id, the vid, and use a random uuid as secret...
  
      # the key + secret must still be private, so we need https here.
      
      redirect '/vi'
    end  

    # XXX: update the user of everything that is being killed.
    delete '/vi/:vid' do
      #stream(:keep_open) do |out|
        # return a eventmachine thing?
        del_virtual_internet(@userid, params[:vid])
        
        # send new data as soon as the cloud provider has it ready
      
        # EventMachine::PeriodicTimer.new(1) { out << "#{Time.now}\n" }
      #end  
      redirect '/vi'    
    end
    
    # trigger upload and restart of software. should supply ALL parameters 
    # for each netapp in the post(!):
    # required: vid, name
    #
    # { "nid" : ["a", "b", "c"], "nid2" : ["a", "b", "c"]}
    post '/vi/:vid/run' do
      puts "params: #{params.inspect}"
      # where do i get the credentials?
      NetappApp.enqueue("run_on_all_netapps", @userid, params[:vid], params[:name], params)
      
      redirect "/vi/#{params[:vid]}"
    end

    # run a script on the virtual internet
    post '/vi/:vid/script' do
      puts "params: #{params.inspect}"
      NetappApp.enqueue("run_script", @userid, params[:vid], params[:name], params)
      
      redirect '/vi'
    end
    
    # cost ticker for the virtual internet
    #
    get '/vi/cost/' do 
      stream(:keep_open) do |out|
        x = 0
        # vm parameter: created_at=Mon Nov 29 18:09:34 -0500 2010
        
        EM::PeriodicTimer.new(20) { out << x; x=x+1 }
      end
    end

    get '/vi/killall' do
      NetappApp.enqueue("killall", @userid)      
    end

    def s(obj)
      if obj
        return obj if obj.is_a?(String)
        return obj.to_json
      end
      ""
    end
  end
end

#      # configure virtual internet controller:
#      #   - set reference state / topology
#      #     - a specification of the network topology
#      #     - a program that iterates to a specific optimimum
#      #   - set network resolver (random, map, optimal): 
#      #     - how to create the netapps that make up the virtual internet
#      #   - set netapp configurator
#      #     - what to run in the virtual internet
#      # start virtual internet controller client
#      #   - start reference 
#    end
#    
