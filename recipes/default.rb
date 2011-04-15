#
# Cookbook Name:: cloudfoundry
# Recipe:: default
#
# Copyright 2011, Ari Lerner
#
# All rights reserved - Do Not Redistribute
#

require 'digest/md5'
 
include_recipe "cloudfoundry::rvm"

cloudfoundry_dir = "#{ENV['HOME']}/cloudfoundry"

directory "#{cloudfoundry_dir}" do
  action :create
end

git "#{cloudfoundry_dir}/vcap" do
  repository "https://github.com/cloudfoundry/vcap.git"
  reference "master"
  action :sync
end 

execute "run submodule update for vcap" do
  cwd "#{cloudfoundry_dir}/vcap"
  command "git submodule update --init"
end

gem_package "vmc"

# Setup vcap
%w(curl libcurl3 bison build-essential zlib1g-dev libssl-dev libreadline5-dev libxml2 libxml2-dev 
    libxslt1.1 libxslt1-dev git-core sqlite3 libsqlite3-ruby libsqlite3-dev unzip zip ruby-full rake).each do |pkg|
  package pkg do
    action :install
  end
end

directory "/var/vcap" do
  mode 0777
end
%w(sys sys/log shared services).each do |dir|
  directory "/var/vcap/#{dir}" do
    recursive true
    mode 0777
  end
end

gem_package "bundler"

# Install Router
include_recipe "nginx"

%w(ruby-dev libmysql-ruby libmysqlclient-dev libpq-dev postgresql-client).each do |pkg|
  package pkg do
    action :install
  end
end


# Build mysql
include_recipe "mysql::server"
%w(mysql-server ruby-dev libmysql-ruby libmysqlclient-dev).each do |pkg|
  package pkg do
    action :install
  end
end
execute "set mysql pass in the mysql_node.yml" do
  cwd "#{cloudfoundry_dir}/vcap/services/mysql/config"
  command "sed -i.bkup -e \"s/pass: root/pass: #{node[:mysql][:server_root_password]}/\" mysql_node.yml"
end
gem_package "mysql"

# Setup postgres
include_recipe "postgresql"
gem_package "pg"

# Install DEA
%w(lsof psmisc librmagick-ruby python-software-properties curl java-common).each do |pkg|
  package pkg do
    action :install
  end
end

apt_repository "partner repositories" do
  uri "http://archive.canonical.com"
  distribution "lucid"
  components ["partner"]
  action :add
end

include_recipe "nodejs"

# Rubygems and support
%w(rack rake thin sinatra eventmachine).each do |gem_pkg|
  gem_package "#{gem_pkg}"
end

directory "/var/vcap.local" do
  recursive true
  mode 0777
end

# Secure directories
directory '/var' do
  mode 0755
end

%w(sys shared).each do |dir|
  directory dir do
    mode 0700
    recursive true
  end
end

directory "/var/vcap.local" do
  mode 0711
  recursive true
end

directory "/var/vcap.local/apps" do
  mode 0711
  recursive true
end

%w(/tmp /var/tmp).each do |dir|
  directory dir do
    mode 0700
  end
end

include_recipe "redis"

%w(erlang rabbitmq mongodb::source).each do |recipe|
  include_recipe recipe
end

# Change nginx
execute "Set nginx conf" do
  user "root"
  cwd "#{cloudfoundry_dir}/vcap"
  command "cp setup/simple.nginx.conf /etc/nginx/nginx.conf && /etc/init.d/nginx restart"
end

execute "Run rake bundler:install in vcap" do
  cwd "#{cloudfoundry_dir}/vcap"
  command "rake bundler:install"
end

execute "Start cloudfoundry" do
  cwd "#{cloudfoundry_dir}/vcap"
  command "bin/vcap start"
end