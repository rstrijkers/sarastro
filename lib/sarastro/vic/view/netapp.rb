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

module VIC
  class NetappApp < VirtualInternetControllerApp
     extend NetappController
     include JobQueue
     include HMACAuth::Helpers
     #register Sinatra::Async
     register HMACAuth

     def static
       self.class
     end
  
     # We need to access the virtual internet data of our superclass
     def vi
       self.class.superclass.vic_vi = {} unless self.class.superclass.vic_vi
       self.class.superclass.vic_vi
     end
     def vi=(val); self.class.superclasss.vic_vi=val; end

     def symbolize_keys(hash)
       hash.inject({}) {|s,(k,v)| s[k.to_sym] = v.is_a?(Hash) ? symbolize_keys(v) : v; s}
     end

     use Rack::MethodOverride  # allow post to simulate put / delete
   
     before '/netapp*' do
       # Either accept hmac authentication or openid: netapps must be able to
       # access these methods.
     
       if hmac_authenticated?         
         @userid = params[:user]
       else
         require_openid_authentication # won't pass this unless authenticated
         unless session[:user_attributes].nil? 
           @userid = session[:user_attributes][:email] 
         else
           @userid = params[:userid] # on localhost we allow login
         end
       end
         
       @vid = params[:vid] 

       return [200, {}, "Context needs vid parameter."] unless @vid
     end

#
# ---- NETAPP MANAGEMENT
#

     # information about all netapps (in openid context) or, when vid in 
     # openid context is supplied, about netapps in a vi
     #
     get '/netapp' do
       [200,{}, s(static.get_netapps(@userid, @vid))]
     end
          
     # arguments:
     #   {filter => {region => "", zone => ""}, name => "vi image postfix"}
     #
     post '/netapp' do
       p = symbolize_keys(params) 
       [200,{}, s(jobqueue.enqueue("create_netapp", @userid, @vid, p))]
     end

     get '/netapp/id/:nid' do 
       [200,{}, s(static.get_netapp(params[:nid]))]
     end
  
     delete '/netapp/id/:nid' do
       # check userid and vid. both are implicit in the call       
       [200,{}, s(jobqueue.enqueue("kill_netapp", @userid, @vid, params[:nid]))]
     end
     
     # trigger upload and restart of software. 
     # required: vid, name
     #
     # { "nid" : ["a", "b", "c"], "nid2" : ["a", "b", "c"]}
     post '/netapp/:nid/run' do
       puts "params: #{params.inspect}"
       na = get_netapp(params.delete("nid"))
       app = params.delete("name")       
       params.delete("splat")
       params.delete("captures")
       
       NetappApp.enqueue("run_on_netapp", @userid, @vid, na, app, params)

       redirect "/vi/#{@vid}"
     end
     
#
# ---- EDGE MANAGEMENT
#    
     get '/netapp/links' do
       puts "get links: #{params.inspect}"
       [200,{}, s(get_links(@userid, @vid))]
     end

     # also allow without authentication
     get '/noauth/netapp/links' do
       puts "get links: #{params.inspect}"
       [200,{}, s(get_links(params[:userid], params[:vid]))]
     end

     # arguments:
     #   { src => "netapp id", dst => "netapp id"}
     #
     post '/netapp/link' do
       p = symbolize_keys(params) 
       puts "add link: #{p.inspect}"
       [200,{}, s(jobqueue.enqueue("create_link", @userid, @vid, p))]
     end
    
     get '/netapp/link/id/:lid' do
       puts "get links: #{params.inspect}"
       [200,{}, s(get_link(params[:lid]))]
     end

     get '/netapp/link/tuple/:lid' do
       puts "get link with tuple: #{params.inspect}"
       
       res = params[:lid].split(":")
       return 200 unless res       
       
       [200,{}, s(get_link_by_tuple(@userid, @vid, res.sort))]
     end
     
     delete '/netapp/link/id/:lid' do
       [200,{}, s(jobqueue.enqueue("kill_link", @userid, @vid, params[:lid]))]
     end

# XXX: this should be provided by the virtual internet
   
    # subscribe to netapp updates usings streams.
    # we could also use pubsubhubbub or some other event notification system,
    # but then we'd be polling again. Better to have some channels open.
    get '/netapp/feed', provides: 'text/event-stream' do
      stream(:keep_open) do |out|                        
        # extend object to accept observer update 
        keep_alive = EM::PeriodicTimer.new(20) { out << "data: pong!\n\n" }

        # update will be called if NetappApp notifies: 
        #    changed
        #    notify_observers(result)
        # XXX: to be tested
        class <<out
          def update(result)
            self << "data: #{result.to_json}\n\n"
          end
        end         
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
   
     # allow url requests to be sent to a netapp for testing without 
     # complicated hmac issues...
     get '/netapp/:nid/query' do
       # do the query.... return the result...
       
       # actually, we can get the netapp by id...
       na = get_netapp(params[:nid]) 
       halt unless na
       hmac = params.delete("hmac")
       path = params.delete("path")
       params.delete("splat")
       params.delete("captures")

       resp = ""
       if hmac == "yes"
         header, url = hmac_query(na[:output][:public_ip_address], :get, path, get_hmac_credentials(na[:input][0], na[:input][1]), params)
      
         begin
           request = Typhoeus::Request.new(url,
             :method        => :get, 
             :headers       => header,
             :params        => params.merge({:id => hmac[:id]}),
             :timeout       => 500)           

           Thread.current[:hydra] ||= Typhoeus::Hydra.new(:max_concurrency => 100)
           hydra = Thread.current[:hydra]
           hydra.queue(request)
           hydra.run
           
           resp = request.response.body
           
#           resp = Net::HTTP.get(URI(signed_url))
         rescue e
           puts "error, try again later: #{e.inspect}"
         end
       else
         begin
           url = "http://#{na[:output][:public_ip_address]}:4567/#{path}"
           puts "calling: #{url}"
           
           request = Typhoeus::Request.new(url, :timeout => 500)           
           Thread.current[:hydra] ||= Typhoeus::Hydra.new(:max_concurrency => 100)
           hydra = Thread.current[:hydra]
           hydra.queue(request)
           hydra.run
           
           resp = request.response.body
           puts "response: #{resp}"
           
#           resp = Net::HTTP.get(URI("http://#{na[:output][:public_ip_address]}:4567/#{path}"))
         rescue
           puts "error, try again later: #{e.inspect}"
         end
       end
       
       [200, {}, resp.nil? ? "" : resp]
     end
     
     get '/netapp/:nid/post' do
       na = get_netapp(params[:nid]) 
       halt unless na
       path = params.delete("path")
       params.delete("splat")
       params.delete("captures")
       res = hmac_post(na[:output][:public_ip_address], path, params, get_hmac_credentials(na[:input][0], na[:input][1]))
         
       resp = Typhoeus::Request.post(res[1],
         :method        => :post,
         :headers       => res[0],
         :params        => params)       
       [200, {}, resp.body]
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