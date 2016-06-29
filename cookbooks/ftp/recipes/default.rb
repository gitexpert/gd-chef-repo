#
# Cookbook Name:: ftp
# Recipe:: default
#
# Copyright 2016, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#
ftp_server           = #{node['ftp']['server']}
ftp_user             = #{node['ftp']['username']}
ftp_password         = #{node['ftp']['password']}
mtx_artifact_file    = #{node['mtx_artifact']['file_name']}

package "Install FTP Client" do
   package_name "ftp"
   action :install
end 

remote_file "#{node['mtx_artifact']['file_destination']}" do
   source "ftp://ftpuser:ftpuser@chef-client1/#{node['mtx_artifact']['file_name']}"
   action :create
end
