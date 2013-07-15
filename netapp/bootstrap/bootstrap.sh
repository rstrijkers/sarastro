#!/usr/bin/env bash
#
#
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
# ubuntu lucid bootstrapping: make sure we have the good sources and install puppet
# for advanced configuration
#
# it's just impossible to account for all the broken distributions....
#
# only solution: test by hand and save the AMI


#### 
#### THIS IS JUST A PLACEHOLDER. CURRENTLY NO PRIORITY TO AUTOMATE THIS. 
#### BOOTSTRAPPED IMAGES LIVE AS AMIs IN EACH PROVIDER AND JUST COPY PAST THE
#### TEXT.
####

##=============================================================================
#echo "Getting Linux distribution..."
#
#if [ -f /etc/lsb-release ]; then
#  . /etc/lsb-release
#  OS=$DISTRIB_ID
#elif [ -f /etc/redhat-release ]; then
#  OS="Red Hat"
#elif [ -f /etc/debian_version ]; then
#  OS="Ubuntu" # treat both debian and ubuntu the same
#else
#  echo "Unsupported Linux distribution"
#  exit 1
#fi
#
#echo "$OS Linux"
#
##=============================================================================
#echo "Installing necessary packages..."
#
#if [[ "$OS" == "Ubuntu" ]]; then
#  sudo apt-get update -y
#
#  # This list is from running 'rvm requirements'
#  sudo apt-get install -y build-essential openssl libreadline6 libreadline6-dev curl zlib1g zlib1g-dev libssl-dev libyaml-dev libsqlite3-0 libsqlite3-dev sqlite3 libxml2-dev libxslt-dev autoconf libc6-dev ncurses-dev automake libtool bison wget rubygems
#elif [[ "$OS" == "Red Hat" ]]; then
#  sudo yum update -y
#
#  # This is for rvm
#  sudo yum install -y git gcc-c++ patch readline readline-devel zlib zlib-devel libyaml-devel libffi-devel openssl-devel make bzip2 autoconf automake libtool bison wget ruby-devel rubygems 
#fi	
#sudo gem install puppet facter --no-rdoc --no-ri
#

# we need a multiverse world...
#echo "deb http://us.archive.ubuntu.com/ubuntu/ lucid main universe multiverse " > /etc/apt/sources.list
# we need non-free....
#=============================================================================
# Debian / Ubuntu

echo "deb http://us-east-1.ec2.archive.ubuntu.com/ubuntu/ oneiric main universe multiverse" > /etc/apt/sources.list

apt-get update 
aptitude -y install puppet unzip
puppet setupaccount.pp

#=============================================================================
# REDHAT i386

#!/usr/bin/env bash
cat > /etc/yum.repos.d/bla.repo <<EOF
[knot]
name=Network.CZ Repository
baseurl=ftp://repo.network.cz/pub/redhat/
enabled=1
gpgcheck=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-network.cz
EOF

wget http://download.fedoraproject.org/pub/epel/6/i386/epel-release-6-5.noarch.rpm
wget http://packages.sw.be/rpmforge-release/rpmforge-release-0.5.2-2.el6.rf.i686.rpm
rpm -ihv epel-release-6-5.noarch.rpm
rpm -ihv rpmforge-release-0.5.2-2.el6.rf.i686.rpm

# with Amazon AMI radvd must be installed manually
wget http://mirror.centos.org/centos/6/os/i386/Packages/radvd-1.6-1.el6.i686.rpm
rpm -ihv radvd-1.6-1.el6.i686.rpm

yum install puppet -y
puppet setupaccount.pp
