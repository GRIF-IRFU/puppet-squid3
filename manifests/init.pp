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
  $cache_dir            = ['ufs /var/cache/squid 20000 16 256'],
  $cache                = [],
  $via                  = 'on',
  $ignore_expect_100    = 'off',
  $cache_mgr            = 'root', #the manager email
  $forwarded_for        = 'on',
  $client_persistent_connections = 'on',
  $server_persistent_connections = 'on',
  $maximum_object_size           = '4096 KB',
  $maximum_object_size_in_memory = '512 KB',
  $memory_replacement_policy = 'lru',
  $cache_replacement_policy  = 'lru',
  $strip_query_terms    = 'on', #or off
  $snmp_port = '0', #use 3401 for enableing and using default port
  $snmp_access ='deny all',
  $dns_nameservers = 'none',
  $memory_pools_limit   = '5 MB',
  $coredump_dir   = 'none',
  $template_name        = 'squid.conf.erb',
  $frontier_template_name = 'squid.conf.frontier.erb',
  $logformat = 'squid', #can be any format defined in the erb, such as awstats
  $nthreads=1, #this is ONLY available for frontier, and will run multiple threads on the same host. Warning, this will clear the cache.
  
) inherits ::squid3::params {

  $cache_dir_paths_1=regsubst($cache_dir,'([a-z]+ +)(.*)','\2')
  $cache_dir_paths=regsubst($cache_dir_paths_1,' .*','')
  #if we're wrong in the regex, this might thown a puppet error : Could not intern from text/pson
  file { $cache_dir_paths :
    ensure => directory,
    mode => 644,
    owner => $user,
    group => $user,
    require => Package[$package_name],
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
    content => $variant ? { /frontier/ => template("squid3/${frontier_template_name}"), default => template("squid3/${template_name}") },
  }

  if($variant == 'frontier') {
    
    #prevent standard squid/frontier collision :
    package{[squid,squid3] : 
      ensure=>absent,
      before=>Package[$package_name],
    }
    
    #disable automatic customization "à la CERN"
    file { '/etc/squid/customize.sh': 
      source => 'puppet:///modules/squid3/customize.sh',
      mode=>755,
      require=>Package[$package_name],
      before=> Service[$service_name],
      }
      
      
    if($nthreads>1) {
       #create a state file that tells us how many squid threads we have, and that will triger a one-time cleanup
       $cache_dirs_bash=inline_template('<%= @cache_dir_paths.map{|k| "\'" + k + "\'"}.join(" ") %>') #this are bash escaped directories
       $squid_number=$nthreads - 1
       
       file { '/var/lib/puppet/state/nthreads.txt': ensure=>present, content => "File created by puppet-squid3. Do *NOT* remove.\nnthreads : $nthreads\n"}
       ~>
       exec { 'cleanup squid cache dirs': #stop squid, cleanup the 1 thread cache dir, cleanup the N-threads cache dirs, make subdirectories 
         command =>
          "/sbin/service $service_name stop 
          for i in $cache_dirs_bash ; do rm -rf \$i/{0,1,2,3,4,5,6,7,8,9,A,B,C,D,E,F}{0,1,2,3,4,5,6,7,8,9,A,B,C,D,E,F} ; done
          for i in $cache_dirs_bash ; do rm -rf \$i/squid* ; done
          for i in $cache_dirs_bash ; do mkdir -p \$i/squid{0..${squid_number}} ; chown ${user}:${user} \$i/squid* ;  done",
          
         refreshonly=>true,
         notify=>Service[$service_name],
         require=>File[$config_file],
         before=>Service[$service_name],
         path => ['/usr/bin','/usr/sbin','/bin','/sbin',],
         logoutput => on_failure,
       }
    }
  }

}

