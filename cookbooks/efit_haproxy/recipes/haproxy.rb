#
# Cookbook Name:: efit_haproxy
# Recipe:: haproxy
#
# Copyright (c) 2015 The Authors, All Rights Reserved.


haproxy_config        = "#{node['efit_haproxy']['haproxy_config_dir']}/haproxy.cfg"
#haproxy_cert_dir      = "#{node['efit_haproxy']['haproxy_cert_dir']}/haproxy_cert_file"
#haproxy_cert_file_prod = "#{node['efit_haproxy']['haproxy_cert_dir']}/haproxy_prod.pem"
haproxy_rootcacert_file  = "#{node['efit_haproxy']['haproxy_cert_dir']}/rootcacert.pem"
haproxy_devicecert_file = "#{node['efit_haproxy']['haproxy_cert_dir']}/haproxy.pem"
haproxy_400_error     = "#{node['efit_haproxy']['haproxy_errors']}/400.http"
haproxy_401_error     = "#{node['efit_haproxy']['haproxy_errors']}/401.http"
haproxy_403_error     = "#{node['efit_haproxy']['haproxy_errors']}/403.http"
haproxy_408_error     = "#{node['efit_haproxy']['haproxy_errors']}/408.http"
haproxy_500_error     = "#{node['efit_haproxy']['haproxy_errors']}/500.http"
haproxy_502_error     = "#{node['efit_haproxy']['haproxy_errors']}/502.http"
haproxy_503_error     = "#{node['efit_haproxy']['haproxy_errors']}/503.http"
haproxy_504_error     = "#{node['efit_haproxy']['haproxy_errors']}/504.http"
env_name = node['efit_haproxy']['env_name']
                  
#Create Haproxy errors directory
directory node['efit_haproxy']['haproxy_errors'] do
  mode 00755
  recursive true
  action :create
end

#Create Haproxy Directory
directory node['efit_haproxy']['haproxy_dir'] do
  mode 00755
  recursive true
  action :create
end

#Create Haproxy SSL certificate  Directory
directory node['efit_haproxy']['haproxy_cert_dir'] do
  mode 00700
  recursive true
  action :create
end

cookbook_file haproxy_rootcacert_file do
  source 'rootcacert.pem'
  mode '00600'
  action :create
end

env_name = env_name.downcase
if env_name == "prod" then
  haproxy_cert_file = "haproxy_prod.pem"
else
  haproxy_cert_file = "haproxy_devqa.pem"
end 

cookbook_file haproxy_devicecert_file do
    source haproxy_cert_file
    mode '00600'
    action :create
end
 
# Configure HAProxy Configuration file
template haproxy_config do
  source "haproxy-config.erb"
  mode "0600"

  variables({
    backend_nodes: search(:node, "chef_environment:#{node.chef_environment} AND role:efit_shipyard_slave").sort_by{ |n| n.name },
    :user => node['efit_haproxy']['user'],
    :group => node['efit_haproxy']['group'],
    :acl_url_pivr_health_path_beg => node['efit_haproxy']['acl_url_pivr_health_path_beg'],
    :acl_url_pivr_path_beg => node['efit_haproxy']['acl_url_pivr_path_beg'],
    :haproxy_frontend_http_port => node['efit_haproxy']['haproxy_frontend_http_port'],
    :haproxy_frontend_https_port => node['efit_haproxy']['haproxy_frontend_https_port'],
    :haproxy_backend_docker_port => node['efit_haproxy']['haproxy_backend_docker_port'],
    :haproxy_http_listen_port => node['efit_haproxy']['haproxy_http_listen_port'],
    :haproxy_timeouts_connect => node['efit_haproxy']['haproxy_timeouts_connect'],
    :haproxy_timeouts_client => node['efit_haproxy']['haproxy_timeouts_client'],
    :haproxy_timeouts_server => node['efit_haproxy']['haproxy_timeouts_server']
    
  
  })
  notifies :reload, 'service[haproxy]'

end

# Configure Haproxy for 400 error
template haproxy_400_error do
  source "400.http.erb"
  mode "0600"
end

# Configure Haproxy for 401 error
template haproxy_401_error do
  source "401.http.erb"
  mode "0600"
end
# Configure Haproxy for 403 error
template haproxy_403_error do
  source "403.http.erb"
  mode "0600"
end
# Configure Haproxy for 408 error
template haproxy_408_error do
  source "408.http.erb"
  mode "0600"
end
# Configure Haproxy for 500 error
template haproxy_500_error do
  source "500.http.erb"
  mode "0600"
end
# Configure Haproxy for 502 error
template haproxy_502_error do
  source "502.http.erb"
  mode "0600"
end
# Configure Haproxy for 503 error
template haproxy_503_error do
  source "503.http.erb"
  mode "0600"
end
# Configure Haproxy for 504 error
template haproxy_504_error do
  source "504.http.erb"
  mode "0600"
end

#Set HAProxy Permissive in SELinux
execute "Set SELinux Context for Journal Path" do
  command "semanage permissive -a haproxy_t 2>/dev/null"
  not_if "semodule -l | grep permissive | grep haproxy_t 2>/dev/null 2>/dev/null"
end

# Start the Haproxy service
service "haproxy" do
  supports :status => true, :restart => true
  action [ :enable, :start ]
end