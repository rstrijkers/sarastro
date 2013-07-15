#!/usr/bin/env/ruby
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
# XXX: refactor 
#
# XXX: credit warden-hmac-authentication, this code is copied almost verbatim.
#      Dependencies on warden have been removed, however.
#

module VIC
  module HMACAuth    
    module Helpers
      def require_hmac_authentication
        auth = get_auth_by_method
        
        if auth.check_ttl? && !auth.timestamp_valid?
          puts "ttl or timestamp invalid"
          redirect "/go_away"
        end
        
        if auth.signature_valid?
          if params[:id]
            # make sure that id is authenticated too (->> self.class.id)
            return true if params[:id] == self.class.config[:id]
          end
        else
          puts "not a valid signature?"
        end

        redirect "/go_away"
      end

      def hmac_authenticated?
        auth = get_auth_by_method
        return false if auth.check_ttl? && !auth.timestamp_valid? 
        return auth.signature_valid?
      end
      
      def get_auth_by_method
        case env['REQUEST_METHOD'].upcase
        when "GET"
          auth = AuthQuery.new
        else
          auth = AuthHeader.new
        end
        
        auth.config = self.class.config
        auth.request = request        
        auth.env = env
        auth
      end
    
      class AuthBase
        attr_accessor :config, :request, :env

        def authenticate!
        if "" == secret.to_s
          debug("authentication attempt with an empty secret")
          return fail!("Cannot authenticate with an empty secret")
        end

        if check_ttl? && !timestamp_valid?
          debug("authentication attempt with an invalid timestamp. Given was #{timestamp}, expected was #{Time.now.gmtime}")
          return fail!("Invalid timestamp")
        end

        if signature_valid?
          success!(retrieve_user)
        else
          debug("authentication attempt with an invalid signature.")
          fail!("Invalid token passed")
        end
      end

      # Retrieve the current request method
      #
      # @return [String] The request method in capital letters
      def request_method
        env['REQUEST_METHOD'].upcase
      end

      # Retrieve the request query parameters
      #
      # @return [Hash] The query parameters
      def params
        request.GET
      end

      # Retrieve the request headers. Header names are normalized by this method by stripping
      # the `HTTP_`-prefix and replacing underscores with dashes. `HTTP_X_Foo` is normalized to
      # `X-Foo`.
      #
      # @return [Hash] The request headers
      def headers
        pairs = env.select {|k,v| k.start_with? 'HTTP_'}
            .collect {|pair| [pair[0].sub(/^HTTP_/, '').gsub(/_/, '-'), pair[1]]}
            .sort
         headers = Hash[*pairs.flatten]
         headers
      end

      # Retrieve a user from the database. Calls the proc given in :retrieve_user, else returns true
      #
      # @return [Mixed] The result of the configured proc, true is no proc was given
      def retrieve_user
        @user ||= config[:retrieve_user].respond_to?(:call) ? config[:retrieve_user].call(self) : true
        @user
      end

      # Log a debug message if a logger is available.
      #
      # @param [String] msg The message to log
      def debug(msg)
        if logger
          logger.debug(msg)
        end
      end

      # Retrieve a logger. Current implementation can
      # only handle Padrino loggers
      #
      # @return [Logger] the logger, nil if none is available
      def logger
        if defined? Padrino
          Padrino.logger
        end
      end

        def auth_param
          config[:auth_param] || "auth"
        end

        def auth_header
          (config[:auth_header] || "Authorization").upcase
        end

        def auth_scheme_name
          config[:auth_scheme] || "HMAC"
        end

        def nonce_header_name
          (config[:nonce_header] || "X-#{auth_scheme_name}-Nonce").upcase
        end

        def alternate_date_header_name
          (config[:alternate_date_header] || "X-#{auth_scheme_name}-Date").upcase
        end

        def optional_headers
          ((config[:optional_headers] || []) + ["Content-MD5", "Content-Type"]).map {|h| h.upcase }
        end

        def auth_header_format
          config[:auth_header_format] || '%{scheme} %{signature}'
        end

        # check whether a nonce is set in the request
        #
        # @return [Bool] True if a nonce was given in the request
        def has_nonce?
          nonce && !nonce.to_s.empty?
        end

        def auth_header_parse
          unless @auth_header_parse
            r = config[:auth_header_parse]

            if !r
              # transforms the auth_header_format to a regular expression
              # that allows [-_+.\w] for each of the segments in the format string
              #
              # '%{scheme} %{signature}' => /(?<scheme>[-_+.\w]+) (?<signature>[-_+.\w]+)/
              #
              split_re = /(?<!%)(%{[^}]+})/
              replace_re = /(?<!%)%{([^}]+)}/

         segments = auth_header_format.split split_re
              segments.each_index do |i; md, key|
                md = replace_re.match(segments[i])
                if ! md.nil?
                  key = md.captures[0].to_sym
                  segments[i] = "(?<#{key}>[-_+.\\w]+)"
                else
                  segments[i] = segments[i].gsub "%%", "%"
                end
              end
              r = Regexp.new segments.join
            end

            @auth_header_parse = r
          end

          @auth_header_parse
        end

        def lowercase_headers

          if @lowercase_headers.nil?
            tmp = headers.map do |name,value|
              [name.downcase, value]
            end
            @lowercase_headers = Hash[*tmp.flatten]
          end

          @lowercase_headers
        end

        def hmac
         ::VIC::HMAC::Signer.new("sha1")
        end

        def algorithm
          config[:algorithm] || "sha1"
        end

        def ttl
          config[:ttl].to_i
        end

        def check_ttl?
          !config[:ttl].nil?
        end

        def timestamp
         DateTime.strptime(request_timestamp, '%a, %d %b %Y %H:%M:%S UTC').to_time unless request_timestamp.nil? || request_timestamp.empty?
        end

        def has_timestamp?
          !timestamp.nil?
        end

        def timestamp_valid?
          now = Time.now.gmtime.to_i
          timestamp.to_i <= (now + clockskew) && timestamp.to_i >= (now - ttl)
        end

        def nonce_required?
          !!config[:require_nonce]
        end

        def secret
          @secret ||= config[:secret].respond_to?(:call) ? config[:secret].call(self) : config[:secret]
        end

        def clockskew
          (config[:clockskew] || 5)
        end          
      end       
         
      class AuthHeader < AuthBase
          # Checks that this strategy applies. Tests that the required
          # authentication information was given.
          #
          # @return [Bool] true if all required authentication information is available in the request
          # @see https://github.com/hassox/warden/wiki/Strategies
          def valid?
            valid = required_headers.all? { |h| headers.include?(h) } && headers.include?("AUTHORIZATION") && has_timestamp?
            valid = valid && scheme_valid?
            valid
          end
          
          def params
            request.params
          end
        
          # Check that the signature given in the request is valid.
          #
          # @return [Bool] true if the request is valid
          def signature_valid?

            #:method => "GET",
            #:date => "Mon, 20 Jun 2011 12:06:11 GMT",
            #:nonce => "TESTNONCE",
            #:path => "/example",
            #:query => {
            # "foo" => "bar",
            # "baz" => "foobared"
            #},
            #:headers => {
            # "Content-Type" => "application/json;charset=utf8",
            # "Content-MD5" => "d41d8cd98f00b204e9800998ecf8427e"
            #}

            hmac.validate_signature(given_signature, {
              :secret => secret,
              :method => request_method,
              :date => request_timestamp,
              :nonce => nonce,
              :path => request.path,
              :query => params,
              :headers => headers.select {|name, value| optional_headers.include? name}
            })
          end

          # retrieve the signature from the request
          #
          # @return [String] The signature from the request
          def given_signature
            parsed_auth_header['signature']
          end

          # parses the authentication header from the request using the
          # regexp or proc given in the :auth_header_parse option. The result
          # is memoized
          #
          # @return [Hash] The parsed header
          def parsed_auth_header
            if @parsed_auth_header.nil?
              @parsed_auth_header = auth_header_parse.match(headers[auth_header]) || {}
            end

            @parsed_auth_header
          end

          # retrieve the nonce from the request
          #
          # @return [String] The nonce or an empty string if no nonce was given in the request
          def nonce
            headers[nonce_header_name]
          end

          # retrieve the request timestamp as string
          #
          # @return [String] The request timestamp or an empty string if no timestamp was given in the request
          def request_timestamp
            headers[date_header]
          end

          private

            def required_headers
              headers = [auth_header]
              headers += [nonce_header_name] if nonce_required?
              headers
            end

            def scheme_valid?
              parsed_auth_header['scheme'] == auth_scheme_name
            end

            def date_header
              if headers.include? alternate_date_header_name
                alternate_date_header_name.upcase
              else
                "DATE"
              end
            end

        end  

        class AuthQuery < AuthBase
          # Checks that this strategy applies. Tests that the required
          # authentication information was given.
          #
          # @return [Bool] true if all required authentication information is available in the request
          # @see https://github.com/hassox/warden/wiki/Strategies
          def valid?
            valid = has_signature?
            valid = valid && has_timestamp? if check_ttl?
            valid = valid && has_nonce? if nonce_required?
            valid
          end

          # Checks that the request contains a signature
          #
          # @return [Bool] true if the request contains a signature
          def has_signature?
            auth_info.include? "signature"
          end

          # Check that the signature given in the request is valid.
          #
          # @return [Bool] true if the request is valid
          def signature_valid?
            hmac.validate_url_signature(request.url, secret)
          end

          # retrieve the authentication information from the request
          #
          # @return [Hash] the authentication info in the request
          def auth_info
            params[auth_param] || {}
          end

          # retrieve the nonce from the request
          #
          # @return [String] The nonce or an empty string if no nonce was given in the request
          def nonce
            auth_info["nonce"] || ""
          end

          # retrieve the request timestamp as string
          #
          # @return [String] The request timestamp or an empty string if no timestamp was given in the request
          def request_timestamp
            auth_info["date"] || ""
          end
        end
      
      
###-----
#
# My stuff!!!
#
###----      
       
        def hmac
         ::VIC::HMAC::Signer.new("sha1")
        end
                  
        # returns array of [header, url]
        def hmac_query(host, method, path, hmac_credentials, params = {})
          query = URI.encode_www_form(params.merge({:id => hmac_credentials[:id]}))          
          m = nil
          case method
          when :get
            return hmac.sign_url("http://#{host}:4567/#{path}?#{query}", hmac_credentials[:key], {:nonce => HMAC::Signer.nonce})
          when :post
            m = "POST"
          when :delete
            m = "DELETE"
          when :put
            m = "PUT"
          end
                    
          header, url = hmac.sign_request("http://#{host}:4567/#{path}?#{query}", hmac_credentials[:key], {:nonce => HMAC::Signer.nonce, :method => m})          
          [header, "http://#{host}:4567/#{path}"]
        end      
      end
        
    # XXX: implement
    # HMAC authentication
      def self.registered(app)
        class << app
          attr_accessor :config, :secret, :id
        end
      
        credentials = {}
        if File.exist?("auth.json")
          credentials = JSON.parse(IO.read("auth.json"), :symbolize_names => true)
        end
        app.config = {
          :clockskew => 120, 
          :ttl => 180, # query is valid for 3 minutes          
        }.merge(credentials)
    
  # XXX: auth.json
      
  #      app.set :root, $root_dir
  #      
        app.helpers HMACAuth::Helpers
  #    
  #      app.use Rack::Session::Cookie
  #      app.use Rack::OpenID
        app.enable :sessions
  #      app.enable :logging
  #      app.enable :inline_templates    
  #
  #      app.enable :logging, :dump_errors
  #      app.set :raise_errors, true
  #    
        app.get '/go_away' do
          [403, {}, ""]
        end
  
  #      app.post '/login' do
  #      end
  #
  #      app.post '' do
  #
  #      end
      end
  end
end