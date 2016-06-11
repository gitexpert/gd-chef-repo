#
# Cookbook Name:: efit_haproxy
# Recipe:: default
#
# Copyright 2016, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#
package "httpd" do
	action:install
end

package "mysql-server" do
	action:install
end

package "php-mysql" do
	action:install
end
