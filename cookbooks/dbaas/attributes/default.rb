#################
# Global attributes
#################
default['location']
default['dbaas']['environment'] = ""
default['dbaas']['application'] = ""
default['dbaas']['service']['type'] = ""
default['dbaas']['service']['path'] = ""
default['dbaas']['service']['file_ext'] = ""
default['dbaas']['cassandra']['clusters'] = ""
default['dbaas']['docker']['network'] = ""
default['dbaas']['jenkins']['job_url'] = ""

#################
# Crassandra attributes
#################
default['dbaas']['cassandra']['home'] = ""
default['dbaas']['cassandra']['user'] = ""
default['dbaas']['cassandra']['uid'] = ""
default['dbaas']['cassandra']['group'] = ""
default['dbaas']['cassandra']['gid'] = ""
default['dbaas']['cassandra']['limits'] = ""
default['dbaas']['cassandra']['lvm']['group'] = ""
default['dbaas']['cassandra']['lvm']['size'] = ""
default['dbaas']['cassandra']['lvm']['filesystem'] = ""

#################
# Elastic Search Attributes
#################
default['dbaas']['elasticsearch']['home'] = ""
default['dbaas']['elasticsearch']['user'] = ""
default['dbaas']['elasticsearch']['uid'] = ""
default['dbaas']['elasticsearch']['group'] = ""
default['dbaas']['elasticsearch']['gid'] = ""
default['dbaas']['elasticsearch']['limits'] = ""
default['dbaas']['elasticsearch']['lvm']['group'] = ""
default['dbaas']['elasticsearch']['lvm']['size'] = ""
default['dbaas']['elasticsearch']['lvm']['filesystem'] = ""


#################
# Mongo Global Attributes
#################
default['dbaas']['mongo']['home'] = ""
default['dbaas']['mongo']['user'] = ""
default['dbaas']['mongo']['uid'] = ""
default['dbaas']['mongo']['group'] = ""
default['dbaas']['mongo']['gid'] = ""
default['dbaas']['mongo']['lvm']['group'] = ""
default['dbaas']['mongo']['lvm']['size'] = ""
default['dbaas']['mongo']['lvm']['filesystem'] = ""
default['dbaas']['service']['type'] = ""
default['dbaas']['service']['path'] = ""
default['dbaas']['service']['file_ext'] = ""

#################
# Mongo Shared Server Attributes
#################
default['dbaas']['mongo_shardsvr']['application'] = ""
default['dbaas']['mongo_shardsvr']['clusters'] = ""

#################
# Mongo Attributes
#################
node['dbaas']['mongo']['limits'] = ""
node['dbaas']['docker']['network'] = ""

#################
# Mongo Config Server attributes
#################
default['dbaas']['mongo_configsvr']['application'] = ""
default['dbaas']['mongo_configsvr']['clusters'] = ""

#################
# Mongo Mongos attributes
#################
default['dbaas']['mongo_mongos']['application'] = ""
default['dbaas']['mongo_mongos']['clusters'] = ""

#################
# Mongo Replica attributes
#################
default['dbaas']['mongo_replica']['application'] = ""
default['dbaas']['mongo_replica']['clusters'] = ""
