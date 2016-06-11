# Shipyard Credentials

default['efit_haproxy']['haproxy_config_dir']= "/etc/haproxy"
default['efit_haproxy']['haproxy_errors']= "/etc/haproxy/errors"
default['efit_haproxy']['haproxy_dir']= "/opt/haproxy-bridge"
default['efit_haproxy']['haproxy_cert_dir']= "/etc/ssl/private"
default['efit_haproxy']['haproxy_listen_port']= "5000"


default['efit_haproxy_prod']['shipyard']['user']="proddadmin"
default['efit_haproxy_prod']['shipyard']['password']="shipyardadminpass"
default['efit_haproxy_dev']['shipyard']['user']="devadmin"
default['efit_haproxy_dev']['shipyard']['password']="shipyardadminpass"
