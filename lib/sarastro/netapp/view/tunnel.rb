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
  class TunnelApp < Sinatra::Base    
    register HMACAuth
    include TunnelController
    
    before '/link*' do      
      require_hmac_authentication
    end

    delete '/link/server/:key' do
      stop_vtun("server", params[:key]) if params[:key]
      
      200
    end

    delete '/link/client/:port/:dest' do
      stop_vtun("client", "#{params[:port]}/#{params[:dest]}") if params[:port] && params[:dest]
      
      200
    end

    get '/link/servers' do
      [200, servers.to_json]      
    end
    
    # returns the port for a client to connect
    post '/link/server' do
      [200, create_server.to_json]
    end          
    
    get '/link/client' do      
      [200, clients.to_json]      
    end
    
    post '/link/client' do
      [200, create_client(params[:dest], params[:port]).to_json]
    end    
  end
end