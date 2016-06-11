name "efit_lamp"
description "A role to configure Apache/MySQL Server"
run_list "recipe[efit_lamp::default]", "recipe[efit_lamp::lampconfig]"
