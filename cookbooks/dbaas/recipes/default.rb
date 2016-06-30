#
# Cookbook Name:: dbaas
# Recipe:: default
#
# Copyright 2016, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#
#
# Cookbook Name:: dbaas
# Recipe:: dsc
#
# Copyright (c) 2016 DreamWorks Animation LLC, All Rights Reserved.

################
# Grab data bags
################
jenkins_api_key = data_bag_item('dbaas', 'api_keys')['jenkins']

#################
# Grab Global attributes
#################
location = node['location']
environment = node['dbaas']['environment']
application = node['dbaas']['application']
cassandra_home = node['dbaas']['cassandra']['home']
cassandra_user = node['dbaas']['cassandra']['user']
cassandra_uid = node['dbaas']['cassandra']['uid']
cassandra_group = node['dbaas']['cassandra']['group']
cassandra_gid = node['dbaas']['cassandra']['gid']
cassandra_limits = node['dbaas']['cassandra']['limits']
lvm_group = node['dbaas']['cassandra']['lvm']['group']
lvm_size = node['dbaas']['cassandra']['lvm']['size']
lvm_filesystem = node['dbaas']['cassandra']['lvm']['filesystem']
service_type = node['dbaas']['service']['type']
service_path = node['dbaas']['service']['path']
service_file_ext = node['dbaas']['service']['file_ext']
cassandra_clusters = node['dbaas']['cassandra']['clusters']
docker_networks = node['dbaas']['docker']['network']
jenkins_job_url = node['dbaas']['jenkins']['job_url']

elasticsearch_home = node['dbaas']['elasticsearch']['home']
elasticsearch_user = node['dbaas']['elasticsearch']['user']
elasticsearch_uid = node['dbaas']['elasticsearch']['uid']
elasticsearch_group = node['dbaas']['elasticsearch']['group']
elasticsearch_gid = node['dbaas']['elasticsearch']['gid']
elasticsearch_limits = node['dbaas']['elasticsearch']['limits']
lvm_group = node['dbaas']['elasticsearch']['lvm']['group']
lvm_size = node['dbaas']['elasticsearch']['lvm']['size']
lvm_filesystem = node['dbaas']['elasticsearch']['lvm']['filesystem']

mongo_home = node['dbaas']['mongo']['home']
mongo_user = node['dbaas']['mongo']['user']
mongo_uid = node['dbaas']['mongo']['uid']
mongo_group = node['dbaas']['mongo']['group']
mongo_gid = node['dbaas']['mongo']['gid']
mongo_limits = node['dbaas']['mongo']['limits']
service_type = node['dbaas']['service']['type']
docker_networks = node['dbaas']['docker']['network']

if node.role?('cassandra')
	create_group = cassandra_group
	create_group_id = cassandra_gid
	create_user = cassandra_user
	create_user_id = cassandra_uid
	create_home = cassandra_home
elseif node.role?('elasticsearch')
	create_group = elasticsearch_group
	create_group_id = elasticsearch_gid
	create_user = elasticsearch_user
	create_user_id = elasticsearch_uid
	create_home = elasticsearch_home
elseif node.role?('mongodb')
	create_group = mongo_group
	create_group_id = mongo_gid
	create_user = mongo_user
	create_user_id = mongo_uid
	create_home = mongo_home
end

group create_group do
  gid create_group_id
  action :create
end

user create_user do
  uid create_user_id
  action :create
end

directory create_home do
  owner create_user
  group create_group
  action :create
end

#########################
# Create cassandra limits
#########################
ulimit_domain cassandra_user do
  filename "90-#{cassandra_user}"
  cassandra_limits.each do |item, types|
    types.each do |type, value|
      rule do
        item item
        type type
        value value
 end
    end
  end
end

###################
# Reload unit files
###################
execute 'systemctl daemon-reload' do
  command 'systemctl daemon-reload'
  action :nothing
  only_if { service_type == 'systemd' }
end

########################
# Create Docker Networks
########################
if !docker_networks.nil?
  docker_networks.each do |network, options|
    docker_network network do
      subnet options['subnet']
      gateway options['gateway']
      driver_opts options['driver_opts']
    end
  end
end

###################
# LVM prerequisites
###################
include_recipe 'lvm::default'

##########################
# The following needs to
# be done for each cluster
##########################

cassandra_clusters.each do |cassandra_cluster, attributes|

  #################
  # Grab attributes
  #################
  docker_image_registry = attributes['docker']['image']['registry']
  docker_image_namespace = attributes['docker']['image']['namespace']
  docker_image_name = attributes['docker']['image']['name']
  docker_image_version = attributes['docker']['image']['version']
  docker_container_cpu_shares = attributes['docker']['container']['cpu_shares']
  docker_container_memory_limit = attributes['docker']['container']['memory_limit']
  docker_container_network = attributes['docker']['container']['network']
  docker_container_ip = attributes['docker']['container']['ip']
  docker_container_data_volume = attributes['docker']['container']['data_volume']
  docker_container_backup_volume = attributes['docker']['container']['backup_volume']
  docker_container_env = {}
  docker_container_label = {}

  ####################
 ####################
  # Derived attributes
  ####################
  lvm_mountpoint = "#{cassandra_home}/#{cassandra_cluster}"
  service_file = "#{cassandra_cluster}#{service_file_ext}"
  service_volume_file = "#{cassandra_cluster}-volumes#{service_file_ext}"
  docker_repo = docker_image_name
  if !docker_image_namespace.empty?
    docker_repo = "#{docker_image_namespace}/#{docker_repo}"
  end
  if !docker_image_registry.empty?
    docker_repo = "#{docker_image_registry}/#{docker_repo}"
  end
  docker_container_label = {
    "application" => application,
    "location" => location,
    "environment" => environment,
    "cluster_name" => cassandra_cluster,
  }
  docker_container_env = {
    "DATACENTER" => location
  }
  docker_container_label.merge!(attributes['docker']['container']['label'])
  docker_container_env.merge!(attributes['docker']['container']['env'])

  #################
  # Generate IP
  # if not provided
  #################
  if docker_container_ip.nil? or docker_container_ip.empty?
    ::Chef::Recipe.send(:include, Dbaas::Helper)
    docker_container_ip = reserve_container_ip(
      :name => cassandra_cluster,
      :network => docker_container_network
    )
    node.default['dbaas']['cassandra']['clusters'][cassandra_cluster]['docker']['container']['ip'] = docker_container_ip
  end

  ############
  # Update DNS
  ############
  params = {
    "parameter" => [
      {
        "name" => "Name",
        "value" => cassandra_cluster
      }, {
        "name" => "Value",
        "value" => docker_container_ip
      }, {
        "name" => "TTL",
        "value" => "10"
      }
    ]
  }

  http_request 'add a record' do
    action :post
url "#{jenkins_job_url}/build?token=#{jenkins_api_key}"
    message "json=#{params.to_json}"
  end

  #######################
  # Create logical volume
  #######################
  lvm_logical_volume cassandra_cluster do
    group lvm_group
    size lvm_size
    filesystem lvm_filesystem
    mount_point lvm_mountpoint
    action :create
  end

  directory lvm_mountpoint do
    owner cassandra_user
    group cassandra_group
    action :create
  end

  ############
  # Pull image
  ############
  docker_image docker_image_name do
    repo docker_repo
    tag docker_image_version
    action :pull_if_missing
  end

  ######################
  # Create service files
  ######################
  template "#{service_path}/#{service_volume_file}" do
    source "#{service_type}-volumes.erb"
    variables(
      :cluster => cassandra_cluster,
      :data_volume => "#{lvm_mountpoint}:#{docker_container_data_volume}",
      :backup_volume => "/db-backups/cassandra:#{docker_container_backup_volume}" #TODO: remove hardcode
    )
    notifies :run, 'execute[systemctl daemon-reload]', :immediately
    notifies :start, "service[#{service_volume_file}]"
  end

  template "#{service_path}/#{service_file}" do
    source "#{service_type}.erb"
    variables(
      :cluster => cassandra_cluster,
      :repo => docker_repo,
      :env => docker_container_env,
      :label => docker_container_label,
      :version => docker_image_version,
      :cpu_shares => docker_container_cpu_shares,
      :network => docker_container_network,
      :ip => docker_container_ip
    )
    notifies :run, 'execute[systemctl daemon-reload]', :immediately
    notifies :restart, "service[#{service_file}]", :immediately
  end

  #################
  # Enable services
 service service_volume_file do
    action [:enable, :nothing]
  end

  service service_file do
    action [:enable, :start]
  end
end unless cassandra_clusters.nil?

#############################
# Create elasticsearch limits
#############################
ulimit_domain elasticsearch_user do
  filename "90-#{elasticsearch_user}"
  elasticsearch_limits.each do |item, types|
    types.each do |type, value|
      rule do
        item item
        type type
        value value
 end
    end
  end
end

###################
# Reload unit files
###################
execute 'systemctl daemon-reload' do
  command 'systemctl daemon-reload'
  action :nothing
  only_if { service_type == 'systemd' }
end

########################
# Create Docker Networks
########################
if !docker_networks.nil?
  docker_networks.each do |network, options|
    docker_network network do
      subnet options['subnet']
      gateway options['gateway']
      driver_opts options['driver_opts']
    end
  end
end

###################
# LVM prerequisites
###################
include_recipe 'lvm::default'

##########################
# The following needs to
# be done for each cluster
##########################

elasticsearch_clusters.each do |elasticsearch_cluster, attributes|

  #################
  # Grab attributes
  #################
  docker_image_registry = attributes['docker']['image']['registry']
  docker_image_namespace = attributes['docker']['image']['namespace']
  docker_image_name = attributes['docker']['image']['name']
  docker_image_version = attributes['docker']['image']['version']
  docker_container_cpu_shares = attributes['docker']['container']['cpu_shares']
  docker_container_memory_limit = attributes['docker']['container']['memory_limit']
  docker_container_network = attributes['docker']['container']['network']
  docker_container_ip = attributes['docker']['container']['ip']
  docker_container_data_volume = attributes['docker']['container']['data_volume']
  docker_container_backup_volume = attributes['docker']['container']['backup_volume']
  docker_container_env = {}
  docker_container_label = {}

  ####################
  # Derived attributes
 ####################
  lvm_mountpoint = "#{elasticsearch_home}/#{elasticsearch_cluster}"
  service_file = "#{elasticsearch_cluster}#{service_file_ext}"
  service_volume_file = "#{elasticsearch_cluster}-volumes#{service_file_ext}"
  docker_repo = docker_image_name
  if !docker_image_namespace.empty?
    docker_repo = "#{docker_image_namespace}/#{docker_repo}"
  end
  if !docker_image_registry.empty?
    docker_repo = "#{docker_image_registry}/#{docker_repo}"
  end
  docker_container_label = {
    "application" => application,
    "location" => location,
    "environment" => environment,
    "cluster_name" => elasticsearch_cluster,
  }
  # Put ES-specific env vars here
  docker_container_env = {}
  docker_container_label.merge!(attributes['docker']['container']['label'])
  docker_container_env.merge!(attributes['docker']['container']['env'])

  #################
  # Generate IP
  # if not provided
  #################
  if docker_container_ip.nil? or docker_container_ip.empty?
    ::Chef::Recipe.send(:include, Dbaas::Helper)
    docker_container_ip = reserve_container_ip(
      :name => elasticsearch_cluster,
      :network => docker_container_network
    )
    node.default['dbaas']['elasticsearch']['clusters'][elasticsearch_cluster]['docker']['container']['ip'] = docker_container_ip
  end

  ############
  # Update DNS
  ############
  params = {
    "parameter" => [
      {
        "name" => "Name",
        "value" => elasticsearch_cluster
      }, {
        "name" => "Value",
        "value" => docker_container_ip
      }, {
        "name" => "TTL",
        "value" => "10"
      }
    ]
  }

  http_request 'add a record' do
    action :post
    url "#{jenkins_job_url}/build?token=#{jenkins_api_key}"
 message "json=#{params.to_json}"
  end

  #######################
  # Create logical volume
  #######################
  lvm_logical_volume elasticsearch_cluster do
    group lvm_group
    size lvm_size
    filesystem lvm_filesystem
    mount_point lvm_mountpoint
    action :create
  end

  directory lvm_mountpoint do
    owner elasticsearch_user
    group elasticsearch_group
    action :create
  end

  ############
  # Pull image
  ############
  docker_image docker_image_name do
    repo docker_repo
    tag docker_image_version
    action :pull_if_missing
  end

  ######################
  # Create service files
  ######################
  template "#{service_path}/#{service_volume_file}" do
    source "#{service_type}-volumes.erb"
    variables(
      :cluster => elasticsearch_cluster,
      :data_volume => "#{lvm_mountpoint}:#{docker_container_data_volume}",
      :backup_volume => "/db-backups/elasticsearch:#{docker_container_backup_volume}" #TODO: remove hardcode
    )
    notifies :run, 'execute[systemctl daemon-reload]', :immediately
    notifies :start, "service[#{service_volume_file}]"
  end

  template "#{service_path}/#{service_file}" do
    source "#{service_type}.erb"
    variables(
      :cluster => elasticsearch_cluster,
      :repo => docker_repo,
      :env => docker_container_env,
      :label => docker_container_label,
      :version => docker_image_version,
      :cpu_shares => docker_container_cpu_shares,
      :network => docker_container_network,
      :ip => docker_container_ip
    )
    notifies :run, 'execute[systemctl daemon-reload]', :immediately
    notifies :restart, "service[#{service_file}]", :immediately
  end

  #################
  # Enable services
  #################
 service service_volume_file do
    action [:enable, :nothing]
  end

  service service_file do
    action [:enable, :start]
  end
end unless elasticsearch_clusters.nil?

#
# Cookbook Name:: dbaas
# Recipe:: mongo
#
# Copyright (c) 2016 DreamWorks Animation LLC, All Rights Reserved.



#####################
# Create mongo limits
#####################
ulimit_domain mongo_user do
  filename "90-#{mongo_user}"
  mongo_limits.each do |item, types|
    types.each do |type, value|
      rule do
        item item
        type type
        value value
      end
    end
  end
end

###################
# Reload unit files
###################
execute 'systemctl daemon-reload' do
  command 'systemctl daemon-reload'
  action :nothing
  only_if { service_type == 'systemd' }
end

########################
# Create Docker Networks
########################
if !docker_networks.nil?
  docker_networks.each do |network, options|
    docker_network network do
      action :nothing
      subnet options['subnet']
      gateway options['gateway']
      driver_opts options['driver_opts']
    end
  end
end

###################
# LVM prerequisites
###################
include_recipe 'lvm::default'

cookbook mongo_configsvr




#
# Cookbook Name:: dbaas
# Recipe:: mongo_configsvr
#
# Copyright (c) 2016 DreamWorks Animation LLC, All Rights Reserved.

include_recipe "dbaas::mongo"

################
# Grab data bags
################
jenkins_api_key = data_bag_item('dbaas', 'api_keys')['jenkins']

#################
# Grab attributes
#################

application = node['dbaas']['mongo_configsvr']['application']
mongo_clusters = node['dbaas']['mongo_configsvr']['clusters']

##########################
# The following needs to
# be done for each cluster
##########################

mongo_clusters.each do |mongo_cluster, attributes|

  #################
  # Grab attributes
  #################
  docker_image_registry = attributes['docker']['image']['registry']
  docker_image_namespace = attributes['docker']['image']['namespace']
  docker_image_name = attributes['docker']['image']['name']
  docker_image_version = attributes['docker']['image']['version']
  docker_container_cpu_shares = attributes['docker']['container']['cpu_shares']
  docker_container_memory_limit = attributes['docker']['container']['memory_limit']
  docker_container_network = attributes['docker']['container']['network']
  docker_container_ip = attributes['docker']['container']['ip']
  docker_container_data_volume = attributes['docker']['container']['data_volume']
  docker_container_env = attributes['docker']['container']['env']
  docker_container_label = {}

  ####################
  # Derived attributes
  ####################
  mongo_replica_name = "#{mongo_cluster}_#{docker_container_env['MONGODB_REPLICA_NAME']}"
  lvm_mountpoint = "#{mongo_home}/#{mongo_cluster}/configsvr"
  service_file = "#{mongo_replica_name}#{service_file_ext}"
  service_volume_file = "#{mongo_replica_name}-volumes#{service_file_ext}"
  service_init_file = "#{mongo_replica_name}-init#{service_file_ext}"
  docker_repo = docker_image_name
  if !docker_image_namespace.empty?
 docker_repo = "#{docker_image_namespace}/#{docker_repo}"
  end
  if !docker_image_registry.empty?
    docker_repo = "#{docker_image_registry}/#{docker_repo}"
  end
  docker_container_label = {
    "application" => application,
    "location" => location,
    "environment" => environment,
    "cluster_name" => mongo_replica_name,
  }
  docker_container_label.merge!(attributes['docker']['container']['label'])

  #################
  # Generate IP
  # if not provided
  #################
  if docker_container_ip.nil? or docker_container_ip.empty?
    ::Chef::Recipe.send(:include, Dbaas::Helper)
    docker_container_ip = reserve_container_ip(
      :name => mongo_replica_name,
      :network => docker_container_network
    )
    node.default['dbaas']['mongo_configsvr']['clusters'][mongo_cluster]['docker']['container']['ip'] = docker_container_ip
  end

  ############
  # Update DNS
  ############
  params = {
    "parameter" => [
      {
        "name" => "Name",
        "value" => mongo_replica_name
      }, {
        "name" => "Value",
        "value" => docker_container_ip
      }, {
        "name" => "TTL",
        "value" => "10"
      }
    ]
  }

  http_request 'add a record' do
    action :post
    url "#{jenkins_job_url}/build?token=#{jenkins_api_key}"
    message "json=#{params.to_json}"
  end

  #######################
  # Create logical volume
  #######################
  lvm_logical_volume mongo_cluster do
    group lvm_group
    size lvm_size
    filesystem lvm_filesystem
 mount_point lvm_mountpoint
    action :create
  end

  directory lvm_mountpoint do
    owner mongo_user
    group mongo_group
    action :create
  end

  ############
  # Pull image
  ############
  docker_image docker_image_name do
    repo docker_repo
    tag docker_image_version
    action :pull_if_missing
  end

  ######################
  # Create service files
  ######################
  template "#{service_path}/#{service_volume_file}" do
    source "#{service_type}-volumes.erb"
    variables(
      :cluster => mongo_replica_name,
      :data_volume => "#{lvm_mountpoint}:#{docker_container_data_volume}"
    )
    notifies :run, 'execute[systemctl daemon-reload]', :immediately
    notifies :start, "service[#{service_volume_file}]"
  end

  template "#{service_path}/#{service_file}" do
    source "#{service_type}.erb"
    variables(
      :cluster => mongo_replica_name,
      :repo => docker_repo,
      :env => docker_container_env,
      :label => docker_container_label,
      :version => docker_image_version,
      :cpu_shares => docker_container_cpu_shares,
      :network => docker_container_network,
      :ip => docker_container_ip
    )
    notifies :run, 'execute[systemctl daemon-reload]', :immediately
    notifies :restart, "service[#{service_file}]", :immediately
  end

  template "#{service_path}/#{service_init_file}" do
    source "#{service_type}-init.erb"
    variables(
      :cluster => mongo_replica_name,
      :repo => docker_repo,
      :env => docker_container_env,
      :label => docker_container_label,
      :version => docker_image_version,
 :cpu_shares => docker_container_cpu_shares,
      :network => docker_container_network
    )
    notifies :run, 'execute[systemctl daemon-reload]', :immediately
  end

  #################
  # Enable services
  #################
  service service_volume_file do
    action [:enable, :nothing]
  end

  service service_file do
    action [:enable, :start]
  end

  service service_init_file do
    action :nothing
  end
end unless mongo_clusters.nil?

application = node['dbaas']['mongo_mongos']['application']
mongo_clusters = node['dbaas']['mongo_mongos']['clusters']

##########################
# The following needs to
# be done for each cluster
##########################

mongo_clusters.each do |mongo_cluster, attributes|

  #################
  # Grab attributes
  #################
  docker_image_registry = attributes['docker']['image']['registry']
  docker_image_namespace = attributes['docker']['image']['namespace']
  docker_image_name = attributes['docker']['image']['name']
  docker_image_version = attributes['docker']['image']['version']
  docker_container_cpu_shares = attributes['docker']['container']['cpu_shares']
  docker_container_memory_limit = attributes['docker']['container']['memory_limit']
  docker_container_network = attributes['docker']['container']['network']
  docker_container_ip = attributes['docker']['container']['ip']
  docker_container_data_volume = attributes['docker']['container']['data_volume']
  docker_container_env = attributes['docker']['container']['env']
  docker_container_label = {}

  ####################
  # Derived attributes
  ####################
  lvm_mountpoint = "#{mongo_home}/#{mongo_cluster}/mongos"
  service_file = "#{mongo_cluster}-mongos#{service_file_ext}"
  service_volume_file = "#{mongo_cluster}-mongos-volumes#{service_file_ext}"
  docker_repo = docker_image_name
  if !docker_image_namespace.empty?
    docker_repo = "#{docker_image_namespace}/#{docker_repo}"
  end
  if !docker_image_registry.empty?
    docker_repo = "#{docker_image_registry}/#{docker_repo}"
  end
  docker_container_label = {
    "application" => application,
    "location" => location,
    "environment" => environment,
    "cluster_name" => mongo_cluster,
  }
  docker_container_label.merge!(attributes['docker']['container']['label'])

  #################
  # Generate IP
  # if not provided
  #################
  if docker_container_ip.nil? or docker_container_ip.empty?
    ::Chef::Recipe.send(:include, Dbaas::Helper)
    docker_container_ip = reserve_container_ip(
      :name => "#{mongo_cluster}-mongos",
      :network => docker_container_network
    )
    node.default['dbaas']['mongo_mongos']['clusters'][mongo_cluster]['docker']['container']['ip'] = docker_container_ip
  end

  ############
  # Update DNS
  ############
  params = {
    "parameter" => [
      {
        "name" => "Name",
        "value" => "#{mongo_cluster}-mongos"
      }, {
        "name" => "Value",
        "value" => docker_container_ip
      }, {
        "name" => "TTL",
        "value" => "10"
      }
    ]
  }

  http_request 'add a record' do
    action :post
    url "#{jenkins_job_url}/build?token=#{jenkins_api_key}"
    message "json=#{params.to_json}"
  end

  #######################
  # Create logical volume
  #######################
  lvm_logical_volume mongo_cluster do
    group lvm_group
    size lvm_size
    filesystem lvm_filesystem
    mount_point lvm_mountpoint
    action :create
  end

  directory lvm_mountpoint do
    owner mongo_user
    group mongo_group
    action :create
  end

  ############
  # Pull image
  ############
  docker_image docker_image_name do
    repo docker_repo
    tag docker_image_version
    action :pull_if_missing
  end

  ######################
  # Create service files
  ######################
  template "#{service_path}/#{service_volume_file}" do
    source "#{service_type}-volumes.erb"
    variables(
      :cluster => "#{mongo_cluster}-mongos",
      :data_volume => "#{lvm_mountpoint}:#{docker_container_data_volume}"
    )
    notifies :run, 'execute[systemctl daemon-reload]', :immediately
    notifies :start, "service[#{service_volume_file}]"
  end

  template "#{service_path}/#{service_file}" do
    source "#{service_type}.erb"
    variables(
      :cluster => "#{mongo_cluster}-mongos",
      :repo => docker_repo,
      :env => docker_container_env,
      :label => docker_container_label,
      :version => docker_image_version,
      :cpu_shares => docker_container_cpu_shares,
      :network => docker_container_network,
      :ip => docker_container_ip
    )
    notifies :run, 'execute[systemctl daemon-reload]', :immediately
    notifies :restart, "service[#{service_file}]", :immediately
  end

  #################
  # Enable services
  #################
  service service_volume_file do
    action [:enable, :nothing]
  end

  service service_file do
    action [:enable, :start]
  end
end unless mongo_clusters.nil?

#
# Cookbook Name:: dbaas
# Recipe:: mongo_replica
#
# Copyright (c) 2016 DreamWorks Animation LLC, All Rights Reserved.

include_recipe "dbaas::mongo"

################
# Grab data bags
################
jenkins_api_key = data_bag_item('dbaas', 'api_keys')['jenkins']

#################
# Grab attributes
#################
location = node['location']
environment = node['environment']
jenkins_job_url = node['dbaas']['jenkins']['job_url']
mongo_home = node['dbaas']['mongo']['home']
mongo_user = node['dbaas']['mongo']['user']
mongo_group = node['dbaas']['mongo']['group']
lvm_group = node['dbaas']['mongo']['lvm']['group']
lvm_size = node['dbaas']['mongo']['lvm']['size']
lvm_filesystem = node['dbaas']['mongo']['lvm']['filesystem']
service_type = node['dbaas']['service']['type']
service_path = node['dbaas']['service']['path']
service_file_ext = node['dbaas']['service']['file_ext']
application = node['dbaas']['mongo_replica']['application']
mongo_clusters = node['dbaas']['mongo_replica']['clusters']

##########################
# The following needs to
# be done for each cluster
##########################

mongo_clusters.each do |mongo_cluster, attributes|

  #################
  # Grab attributes
  #################
  docker_image_registry = attributes['docker']['image']['registry']
  docker_image_namespace = attributes['docker']['image']['namespace']
  docker_image_name = attributes['docker']['image']['name']
  docker_image_version = attributes['docker']['image']['version']
  docker_container_cpu_shares = attributes['docker']['container']['cpu_shares']
  docker_container_memory_limit = attributes['docker']['container']['memory_limit']
  docker_container_network = attributes['docker']['container']['network']
  docker_container_ip = attributes['docker']['container']['ip']
  docker_container_data_volume = attributes['docker']['container']['data_volume']
  docker_container_env = attributes['docker']['container']['env']
  docker_container_label = {}

  ####################
  # Derived attributes
  ####################
  mongo_replica_name = "#{mongo_cluster}_#{docker_container_env['MONGODB_REPLICA_NAME']}"
  lvm_mountpoint = "#{mongo_home}/#{mongo_cluster}/replica"
  service_file = "#{mongo_replica_name}#{service_file_ext}"
  service_volume_file = "#{mongo_replica_name}-volumes#{service_file_ext}"
  docker_repo = docker_image_name
  if !docker_image_namespace.empty?
    docker_repo = "#{docker_image_namespace}/#{docker_repo}"
 end
  if !docker_image_registry.empty?
    docker_repo = "#{docker_image_registry}/#{docker_repo}"
  end
  docker_container_label = {
    "application" => application,
    "location" => location,
    "environment" => environment,
    "cluster_name" => mongo_replica_name,
  }
  docker_container_label.merge!(attributes['docker']['container']['label'])

  #################
  # Generate IP
  # if not provided
  #################
  if docker_container_ip.nil? or docker_container_ip.empty?
    ::Chef::Recipe.send(:include, Dbaas::Helper)
    docker_container_ip = reserve_container_ip(
      :name => mongo_replica_name,
      :network => docker_container_network
    )
    node.default['dbaas']['mongo_replica']['clusters'][mongo_cluster]['docker']['container']['ip'] = docker_container_ip
  end

  ############
  # Update DNS
  ############
  params = {
    "parameter" => [
      {
        "name" => "Name",
        "value" => mongo_replica_name
      }, {
        "name" => "Value",
        "value" => docker_container_ip
      }, {
        "name" => "TTL",
        "value" => "10"
      }
    ]
  }

  http_request 'add a record' do
    action :post
    url "#{jenkins_job_url}/build?token=#{jenkins_api_key}"
    message "json=#{params.to_json}"
  end
  #######################
  # Create logical volume
  #######################
  lvm_logical_volume mongo_cluster do
    group lvm_group
    size lvm_size
    filesystem lvm_filesystem
    mount_point lvm_mountpoint
    action :create
  end

  directory lvm_mountpoint do
    owner mongo_user
    group mongo_group
    action :create
  end

  ############
  # Pull image
  ############
  docker_image docker_image_name do
    repo docker_repo
    tag docker_image_version
    action :pull_if_missing
  end

  ######################
  # Create service files
  ######################
  template "#{service_path}/#{service_volume_file}" do
    source "#{service_type}-volumes.erb"
    variables(
      :cluster => mongo_replica_name,
      :data_volume => "#{lvm_mountpoint}:#{docker_container_data_volume}"
    )
    notifies :run, 'execute[systemctl daemon-reload]', :immediately
    notifies :start, "service[#{service_volume_file}]"
  end

  template "#{service_path}/#{service_file}" do
    source "#{service_type}.erb"
    variables(
      :cluster => mongo_replica_name,
      :repo => docker_repo,
      :env => docker_container_env,
      :label => docker_container_label,
      :version => docker_image_version,
      :cpu_shares => docker_container_cpu_shares,
      :network => docker_container_network,
      :ip => docker_container_ip
    )
    notifies :run, 'execute[systemctl daemon-reload]', :immediately
    notifies :restart, "service[#{service_file}]", :immediately
  end
  #################
  # Enable services
  #################
  service service_volume_file do
    action [:enable, :nothing]
  end

  service service_file do
    action [:enable, :start]
  end
end unless mongo_clusters.nil?

#
# Cookbook Name:: dbaas
# Recipe:: mongo_shardsvr
#
# Copyright (c) 2016 DreamWorks Animation LLC, All Rights Reserved.

application = node['dbaas']['mongo_shardsvr']['application']
mongo_clusters = node['dbaas']['mongo_shardsvr']['clusters']

##########################
# The following needs to
# be done for each cluster
##########################

mongo_clusters.each do |mongo_cluster, attributes|

  #################
  # Grab attributes
  #################
  docker_image_registry = attributes['docker']['image']['registry']
  docker_image_namespace = attributes['docker']['image']['namespace']
  docker_image_name = attributes['docker']['image']['name']
  docker_image_version = attributes['docker']['image']['version']
  docker_container_cpu_shares = attributes['docker']['container']['cpu_shares']
  docker_container_memory_limit = attributes['docker']['container']['memory_limit']
  docker_container_network = attributes['docker']['container']['network']
  docker_container_ip = attributes['docker']['container']['ip']
  docker_container_data_volume = attributes['docker']['container']['data_volume']
  docker_container_env = attributes['docker']['container']['env']
  docker_container_label = {}

  ####################
  # Derived attributes
  ####################
  mongo_replica_name = "#{mongo_cluster}_#{docker_container_env['MONGODB_REPLICA_NAME']}"
  lvm_mountpoint = "#{mongo_home}/#{mongo_cluster}/shardsvr"
  service_file = "#{mongo_replica_name}#{service_file_ext}"
  service_volume_file = "#{mongo_replica_name}-volumes#{service_file_ext}"
  service_init_file = "#{mongo_replica_name}-init#{service_file_ext}"
  docker_repo = docker_image_name
  if !docker_image_namespace.empty?
 docker_repo = "#{docker_image_namespace}/#{docker_repo}"
  end
  if !docker_image_registry.empty?
    docker_repo = "#{docker_image_registry}/#{docker_repo}"
  end
  docker_container_label = {
    "application" => application,
    "location" => location,
    "environment" => environment,
    "cluster_name" => mongo_replica_name,
  }
  docker_container_label.merge!(attributes['docker']['container']['label'])

  #################
  # Generate IP
  # if not provided
  #################
  if docker_container_ip.nil? or docker_container_ip.empty?
    ::Chef::Recipe.send(:include, Dbaas::Helper)
    docker_container_ip = reserve_container_ip(
      :name => mongo_replica_name,
      :network => docker_container_network
    )
    node.default['dbaas']['mongo_shardsvr']['clusters'][mongo_cluster]['docker']['container']['ip'] = docker_container_ip
  end

  ############
  # Update DNS
  ############
  params = {
    "parameter" => [
      {
        "name" => "Name",
        "value" => mongo_replica_name
      }, {
        "name" => "Value",
        "value" => docker_container_ip
      }, {
        "name" => "TTL",
        "value" => "10"
      }
    ]
  }

  http_request 'add a record' do
    action :post
    url "#{jenkins_job_url}/build?token=#{jenkins_api_key}"
    message "json=#{params.to_json}"
  end

  #######################
  # Create logical volume
  #######################
  lvm_logical_volume mongo_cluster do
    group lvm_group
    size lvm_size
    filesystem lvm_filesystem
mount_point lvm_mountpoint
    action :create
  end

  directory lvm_mountpoint do
    owner mongo_user
    group mongo_group
    action :create
  end

  ############
  # Pull image
  ############
  docker_image docker_image_name do
    repo docker_repo
    tag docker_image_version
    action :pull_if_missing
  end

  ######################
  # Create service files
  ######################
  template "#{service_path}/#{service_volume_file}" do
    source "#{service_type}-volumes.erb"
    variables(
      :cluster => mongo_replica_name,
      :data_volume => "#{lvm_mountpoint}:#{docker_container_data_volume}"
    )
    notifies :run, 'execute[systemctl daemon-reload]', :immediately
    notifies :start, "service[#{service_volume_file}]"
  end

  template "#{service_path}/#{service_file}" do
    source "#{service_type}.erb"
    variables(
      :cluster => mongo_replica_name,
      :repo => docker_repo,
      :env => docker_container_env,
      :label => docker_container_label,
      :version => docker_image_version,
      :cpu_shares => docker_container_cpu_shares,
      :network => docker_container_network,
      :ip => docker_container_ip
    )
    notifies :run, 'execute[systemctl daemon-reload]', :immediately
    notifies :restart, "service[#{service_file}]", :immediately
  end

  template "#{service_path}/#{service_init_file}" do
    source "#{service_type}-init.erb"
    variables(
      :cluster => mongo_replica_name,
      :repo => docker_repo,
      :env => docker_container_env,
      :label => docker_container_label,
      :version => docker_image_version,
 :cpu_shares => docker_container_cpu_shares,
      :network => docker_container_network
    )
    notifies :run, 'execute[systemctl daemon-reload]', :immediately
  end

  #################
  # Enable services
  #################
  service service_volume_file do
    action [:enable, :nothing]
  end

  service service_file do
    action [:enable, :start]
  end

  service service_init_file do
    action :nothing
  end
end unless mongo_clusters.nil?
