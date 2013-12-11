# Class: squid3
#
# Squid 3.x proxy server.
#
# Sample Usage :
#     include squid3
#
#     class { 'squid3':
#       acl => [
#         'de myip 192.168.1.1',
#         'fr myip 192.168.1.2',
#         'office src 10.0.0.0/24',
#       ],
#       http_access => [
#         'allow office',
#       ],
#       cache => [ 'deny all' ],
#       via => 'off',
#       tcp_outgoing_address => [
#         '192.168.1.1 country_de',
#         '192.168.1.2 country_fr',
#       ],
#       server_persistent_connections => 'off',
#     }
#
class squid3 (
  # Options are in the same order they appear in squid.conf
  $http_port            = [ '3128' ],
  $acl                  = [],
  $http_access          = [],
  $icp_access           = [],
  $tcp_outgoing_address = [],
  $cache_mem            = '256 MB',
  $cache_dir            = [],
  $cache_dir_name       = '/var/spool/squid',
  $cache                = [],
  $via                  = 'on',
  $ignore_expect_100    = 'off',
  $cache_mgr            = 'root',
  $forwarded_for        = 'on',
  $client_persistent_connections = 'on',
  $server_persistent_connections = 'on',
  $maximum_object_size           = '4096 KB',
  $maximum_object_size_in_memory = '512 KB',
  $memory_replacement_policy = 'lru',
  $cache_replacement_policy  = 'lru',
  $strip_query_terms    = 'on',
  $snmp_port = '0',
  $snmp_access ='deny all',
  $dns_nameservers = 'none',
  $memory_pools_limit   = '5 MB',
  $coredump_dir   = 'none',
  $template_name        = 'squid.conf.erb',
) inherits ::squid3::params {

  file { $cache_dir_name :
    ensure => directory,
    mode => 644,
    owner => 'squid',
    group => 'squid',
    require => Package[$package_name]
  }
  
  package { $package_name: 
    ensure => installed, 
  }
  
  service { $service_name:
    enable    => true,
    ensure    => running,
    restart   => "service ${service_name} reload",
    path      => ['/sbin', '/usr/sbin'],
    hasstatus => true,
    require   => Package[$package_name],
  }

  file { $config_file:
    require => Package[$package_name],
    notify  => Service[$service_name],
    content => template("squid3/${template_name}"),
  }

}

