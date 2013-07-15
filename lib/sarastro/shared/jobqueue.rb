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
# We're mixing connections here... For the blocking redis pop a new connection
# is needed, but should be refactored  

module VIC
  module JobQueue
    def self.included(base)      
      class << base
        
        include Observable
        
        attr_accessor :redis
        attr_reader :queue_name
        
        def supervise(name)
          @queue_name = name
          @observers = []
          @redis = EM::Hiredis.connect
          @redis.sadd("queues", "#{self}")

          puts "#{self} - #{@queue_name}: Checking integrity"
          job_queue_check_integrity

          puts "#{self} - #{@queue_name}: Started job supervisor for class"
        
          next_job = lambda do               
#            puts "#{queue_length} pending for queue #{@queue_name}"
            @redis.blpop("queue:#{@queue_name}", 60) do |data|
              if data.nil?  # timeout, try again
                EM.next_tick &next_job; 
                next
              end

######
## Here blocking and non-blocking is mixed, so active might be written after
# the job is done... how to figure that out...

              # execute the blocking method              
              EM.defer(proc {
                input = REDIS.hget("queue:#{@queue_name}:data", data[1])                
                data = JSON.parse(input, :symbolize_names => true)
                puts "execute worker with request id: #{data[:requestid]}"

                if respond_to?(data[:job])    
                  REDIS.multi do
                    REDIS.hset("queue:#{@queue_name}:data", data[:requestid], data.merge({:status => "active", :start => Time.now}).to_json)              
                    # must be synchronous, because when the job is done the 'active' 
                    # queue message might still be scheduled
                    REDIS.srem("queue:#{@queue_name}:pending", data[:requestid])
                    REDIS.sadd("queue:#{@queue_name}:active", data[:requestid])
                  end
                  start = Time.now              
                  data = data.merge({:output => send(data[:job], *data[:input]), :start => start})
                else
                  REDIS.multi do
                    REDIS.hset("queue:#{@queue_name}:data", data[:requestid], data.merge({:status => "failed", :start => Time.now}).to_json)              
                    # must be synchronous, because when the job is done the 'active' 
                    # queue message might still be scheduled
                    REDIS.srem("queue:#{@queue_name}:pending", data[:requestid])
                  end
                  
                  data = data.merge({
                    :message => "no such method in #{self}: #{data[:job]}"
                  })
                end
                data
              },
              proc {|result|
                r = result.merge({:status => "done", :end => Time.now})
                REDIS.multi do
                  REDIS.hset("queue:#{@queue_name}:data", result[:requestid], r.to_json)
                  REDIS.srem("queue:#{@queue_name}:active", result[:requestid])
                  REDIS.sadd("queue:#{@queue_name}:done", result[:requestid])
                end
                puts "finished job #{result[:requestid]}"
                
                notify_observers(r)
              })
              EM.next_tick &next_job       
            end
          end
          EM.next_tick &next_job # start loop
        end
          
        def queues
          @redis.smembers(@queue_name)
        end

        # XXX: empty args?
        def enqueue(job, *args)
          puts "args: #{args}"
          puts "enqueue: queue:#{@queue_name}:pending - #{job}"
          reqid = REDIS.incr("queue:#{@queue_name}:id")
          REDIS.multi do
            REDIS.rpush("queue:#{@queue_name}", reqid)
            REDIS.sadd("queue:#{@queue_name}:pending", reqid)
            REDIS.hset("queue:#{@queue_name}:data", reqid, {
              :job => job, 
              :requestid => reqid, 
              :input => args.push(reqid),
              :status => "pending"
            }.to_json)
          end
          reqid
        end

        [:pending, :active, :done].each {|m|
            send :define_method, m do
              REDIS.smembers("queue:#{m.to_s}:pending")
            end
        }

        def queue_length
          l = 0
          f = Fiber.new do
            self.redis.llen("queue:#{@queue_name}") { |res|
              l = res
              f.resume
            }
            Fiber.yield
          end
          f.resume
          l
        end

        # only clear pending jobs
        def clear_queue
          REDIS.multi do
            REDIS.del("queue:#{@queue_name}")            
            REDIS.del("queue:#{@queue_name}:pending")
            REDIS.srem("queues", "queue:#{@queue_name}")            
          end
        end

        # XXX
        def job_status(requestid)
          if REDIS.hexists("queue:#{@queue_name}:data", requestid)
            return REDIS.hget("queue:#{@queue_name}:data", requestid)[:status]
          end
          return "unknown"
        end
    
        # clean up any left state:
        #   -> resubmit pending jobs
        #   - keep previously active jobs
        #     - can't say what state they were in, but if vms succeeded, we
        #     can match them to the requests
        #   - keep jobs that were done
        #  
        #   - the netapps list cannot be kept consistent without the
        #     vms...
        #
        # This blocks because we need to have consistent state before starting.
        def job_queue_check_integrity
          # unset mutex
          REDIS.set("bbox:cloudip:mutex", "free")
          
          pending = REDIS.smembers("queue:#{@queue_name}:pending")
          q = []
          if pending
            pending.each {|j| 
              data = REDIS.hget("queue:#{@queue_name}:data", j)
              if data
                REDIS.srem("queue:#{@queue_name}:pending", j)
                d = JSON.parse(data, :symbolize_names => true)               
                q.push([d[:job], *d[:input][0..-2]])
              else 
                REDIS.hdel("queue:#{@queue_name}:data", j)
              end
            }
          end
          q.each {|j| enqueue(*j)}
        end
        
        # Filter must be on userid and virtual internet
        #
#      def add_observer(obj, filter)
#        @observers << {:obj => obj, :filter => filter}
#      end
#      
#      def del_observer(obj)
#        idx = @observers.index {|i| i[:obj] == obj}
#        @observers.delete_at(idx)
#      end
#      
#      # We need observers here, so we can connect, reconnect to events
#      # when necessary.
#      def notify_observers(result)
#        @observers.each {|o|
#          unless o[:filter]
#            o[:obj].update(result)
#            next
#          end
#          
#          call = 0
#          args = 0
#          if o[:filter][:userid]
#            args+=1
#            if o[:filter][:userid] == result[:input][0]
#              call+=1
#            end
#          end
#
#          if o[:filter][:vid]
#            args+=1
#            if o[:filter][:vid] == result[:input][1]
#              call+=1
#            end
#          end
#          
#          if args == call
#            o[:obj].update(result)
#          end
#        }
#      end   
        def dispatch_event(call, data)
          changed
          notify_observers("#{call} #{data}")
        end
   
      end
    end
            
    def jobqueue
      self.class
    end    
  end
end