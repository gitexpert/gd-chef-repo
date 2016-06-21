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

default['efit_haproxy']['haproxy_frontend_http_port']="80"
default['efit_haproxy']['haproxy_frontend_https_port']="443"

default['efit_haproxy']['haproxy_backend_docker_port']="11720"

# SSL Certificate Credentials and Attributes
default['efit_haproxy']['java_keystore_file']="efitpayment-rtmid.jks"
default['efit_haproxy']['java_keystore_alias']="efitpayment-rtm"
default['efit_haproxy']['java_keystore_storepass']="efitrtm"
default['efit_haproxy']['rootcacert_file']="rootcacert.pem"
default['efit_haproxy']['rootcacert_keypass']="efitrtm"
default['efit_prod']['haproxy_cert_env_domain']="eapi-ptsb.kdc.capitalone.com"
default['efit_qa']['haproxy_cert_env_domain']="eapi-ptsb-qa.kdc.capitalone.com"
default['efit_dev']['haproxy_cert_env_domain']="eapi-ptsb-dev.kdc.capitalone.com"
