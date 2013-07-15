#!/usr/bin/env ruby
#
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

OpenID.fetcher.ca_file = "curl-ca-bundle.crt"

module VIC
  module OpenIDAuth    
    module Helpers
      def require_openid_authentication
        if request.host == "localhost" && params[:userid]
          puts "local request: #{request.host} with user id: #{@params[:userid]}"
          return true
        end
        
        redirect '/login' unless openid_authenticated?
      end

      # Check if user authenticated
      def openid_authenticated?
        !session[:openid].nil? && !session[:user_attributes].nil?
      end

      # Constructs an absolute URL to a path in the app
      def url_for(path)
        url = request.scheme + "://"
        url << request.host

        scheme, port = request.scheme, request.port
        if scheme == "https" && port != 443 ||
            scheme == "http" && port != 80
          url << ":#{port}"
        end
        url << path
        url
      end
    end

    # Handle login form & navigation links from Google Apps
    def self.registered(app)
      app.set :root, $root_dir
      
      app.helpers OpenIDAuth::Helpers
 
      app.use Rack::Session::Pool   
      app.use Rack::OpenID
      app.enable :sessions
      app.enable :logging
      app.enable :inline_templates    

      app.enable :logging, :dump_errors
      app.set :raise_errors, true
      app.set :session_secret, "here be dragons"
      
      app.get '/login' do
        erb :login
      end
  
      app.post '/login' do
        puts "open_id id: #{params["openid_identifier"]}"
  
        if params["openid_identifier"].nil?
          # No identifier, just render login form
          erb :login
        else
          # Have provider identifier, tell rack-openid to start OpenID process
          headers 'WWW-Authenticate' => Rack::OpenID.build_header(
            :identifier => params["openid_identifier"],
            :required => ["http://axschema.org/contact/email",
                          "http://axschema.org/namePerson/first",
                          "http://axschema.org/namePerson/last"],
            :return_to => url_for('/openid/complete'),
            :method => 'post')
          halt 401, 'Authentication required.'
        end
      end

      # Handle the response from the OpenID provider
      app.post '/openid/complete' do
        resp = request.env["rack.openid.response"]
        if resp.status == :success          
          session[:openid] = resp.display_identifier
          ax = OpenID::AX::FetchResponse.from_success_response(resp)
          session[:user_attributes] = {
            :email => ax.get_single("http://axschema.org/contact/email"),
            :first_name => ax.get_single("http://axschema.org/namePerson/first"),
            :last_name => ax.get_single("http://axschema.org/namePerson/last")
          }
          redirect '/'
        else
          "Error: #{resp.status}"
        end
      end
    end
  end
end
