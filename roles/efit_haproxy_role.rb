name "efit_haproxy"
description "A role to configure HA Proxy Server"
run_list "recipe[efit_haproxy::default]", "recipe[efit_haproxy::haproxy]"
