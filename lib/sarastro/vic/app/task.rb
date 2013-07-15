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
# Used to manage local configurations. In general, any configuration step
# will require some files and one point of entry, the run script
#
# Here, tasks can be specified that solve certain problems, i.e.
#   - upload new version of sarastro_app
#   - reload sarastro_app
#
#   - upload router configuration
#   - install router software and start routing daemon
#
# expects netapp/apps in the directory in which sarastro was started
#
# Netapps are composed of a template file (erb) and a file (json) to list the
# file dependencies. The templates are parameterized through the erb and are
# made executable.
# 

module VIC
  module NetappRunner
    PATH = "./netapp/apps/" 
    TMPDIR = "/tmp"
    
    def self.list
      # we'll find those in ./netapp/apps
      Dir["#{PATH}*.erb"].map {|f| File.basename(f, ".erb") }
    end
    
    # the idea here is that ERB must have a binding with only the variables
    # from the params. To create a binding with only the variables, we create
    # an anonymous class, define the methods, and return a binding of the 
    # instance. This should result in a binding with only params! 
    def self.make_binding(params)
      Class.new {
      	params.each_pair {|k,v|
      		define_method(k) { 	v }
      	}

      	def bind
      	  instance_eval { binding }
      	end
      }.new.bind
    end

    def self.upload(ip, username, src, dst)
      if ip == nil || ip.empty?
        puts "no IP! Bogus VM!"
        return nil
      end
      catch(:done) {
        loop {
          begin
            puts "uploading to #{ip}: #{src} -> #{dst}"
            Fog::SCP.new(ip, username, {:timeout => 10}).upload(src, dst)
            throw :done
          rescue Errno::ECONNREFUSED
            puts "Connection refused, waiting for machine to come up..."
            sleep 1                        
          rescue Exception => e
            puts "Could not connect, stopping: #{e.message}"
            throw :done
          end
        }      
      }
    end

    # parameters can be used to setup files or to fill out templates.
    # params come in a hash, and all the variables for the specific app should
    # be defined.
    # netapp data should contain the data structure that we know internally.
    # 
    # Prepare:
    #   create binding from params
    #   generates the final executable
    #     - takes the run.erb > run
    #
    def self.run(userid, vid, netappdata, name, params = {})
      return nil unless name # can't continue without a name
      ip = netappdata[:output][:public_ip_address]

      #puts Dir.pwd

      # prepare executable, required files will be in params[:name].tgz
      script = make_script(params.merge({:name => name}))
      if script
        puts script                              
        upload(ip, "rudolf", script, "#{name}")
        del_file(script)
      else
        return nil
      end
  
      # prepare the bundle      
      tgz = make_bundle(name)
      if tgz
        puts tgz
        upload(ip, "rudolf", tgz, "#{name}.tgz")
        del_file(tgz)
      end  
        
      # execute script: 
      #   - don't check known hosts (ip's may be reused)
      #   - use bash --login -c to execute with rvm context available
      #   - nohup with stderr redirect to detach process from ssh session
      `ssh rudolf@#{ip} -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no 'bash --login -c "nohup ./#{name} < /dev/null > #{name}-init.log 2>&1 &"'`
    end
    
    def self.make_script(params, path = PATH)
      script = nil      
      
      begin
        script = ERB.new(File.read("#{path}#{params[:name]}.erb")).result(make_binding(params))
      rescue Exception => e 
        puts "Cannot compile template: #{path}#{params[:name]}.erb"
        puts e.message 
        puts e.backtrace.inspect
        return nil
      end
      
      file = get_a_temp_path("netapp")
      File.open(file, "w") {|f|
        f.write(script)
      }
      File.chmod(0755, file)
      file
    end
    
    # run a local script
    # parameters are substituted with the templating engine
    #
    def self.run_local(params)
      # prepare executable
      script = make_script(params, "./netapp/scripts/")
      if script
        puts script                              
      else
        return nil
      end
      
      # execute script
      result = `#{script}`
      
      puts "ran script: #{result}"
      
      del_file(script)

      result
    end
    
    # tar the required files, all file are relative to the root directory
    def self.make_bundle(name)
      return nil unless File.exist? "#{PATH}#{name}.json"
        
      data = JSON.parse(File.read("#{PATH}#{name}.json"), :symbolize_names => true)
      return nil unless data[:files]

      tmpfile = get_a_temp_path(name)
            
      unless `tar zcf #{tmpfile} #{data[:files].join(" ")} 2>&1`.empty?
        puts "Could not compress files: #{data[:files].join(" ")} from current path: #{Dir.pwd}"
        return nil
      end
      
      tmpfile
    end

    def self.del_file(file)
      # File.delete(file)
    end

    def self.get_a_temp_path(name)
      f = Tempfile.new(name, "/tmp")
      path = f.path
      f.close!
      path
    end

    # should maybe generalize this so that we have an interface to upload
    # bundles and execute programs.
    def self.prepare_and_run_all(userid, vid, rid)
      if nas = get_netapps(userid, vid)
        puts nas.inspect
        nas.each {|na|
          puts "enqueing for netapp: #{na[:requestid]}"
          next if na.nil? || na.empty?
          NetappApp.enqueue("prepare_and_run", userid, vid, na[:requestid])
        }
      end
    end
  end
end