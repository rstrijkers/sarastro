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


# works only on linux
def killallsubprocesses(pid)
  if `uname`.strip == "Darwin"
    `kill -9 #{pid}`
    return
  end
  
  # if there is no pid, we are done
  pids = []
  new_pid = pid
  begin
    tmp = `ps -o pid --no-headers --ppid #{new_pid}`.split("\n")
    break if tmp.empty?
    pids.push tmp
    new_pid = tmp
  end while true

  # remove duplicates and make into list
  pids = pids.flatten.uniq
  puts "found pids: #{pids.inspect}"

  begin
    cp = pids.pop
    puts "sudo kill -9 #{cp}"
    `sudo kill -9 #{cp}`
    break if pids.empty?
  end while true unless pids.empty?
  puts "kill parent: #{pid}"
  `sudo kill -9 #{pid}`
end

killallsubprocesses(ARGV[0])