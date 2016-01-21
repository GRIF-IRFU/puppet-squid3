# Class: squid3
#
class squid3 (
  # Options are in the same order they appear in squid.conf
$use_deprecated_opts           = true,
  $http_port                     = [ '3128' ],
  $https_port                    = [],
  $acl                           = [],
  $ssl_ports                     = [ '443' ],
  $safe_ports                    = [ '80', '21', '443', '70', '210', '1025-65535', '280', '488', '591', '777', ],
  $http_access                   = [],
  $icp_access                    = [],
  $tcp_outgoing_address          = [],
  $cache_mem                     = '256 MB',
  $cache_dir                     = [],
  $cache                         = [],
  $via                           = 'on',
  $ignore_expect_100             = 'off',
  $cache_mgr                     = 'root',
  $forwarded_for                 = 'on',
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
  $user=$::squid3::params::user,
  $variant = $::squid3::params::variant,
  $logformat = 'squid', #can be any format defined in the erb, such as awstats
  $nthreads=1, #this is ONLY available for frontier, and will run multiple threads on the same host. Warning, this will clear the cache.
  $config_hash                   = {},
  $refresh_patterns              = [],
  $template                      = 'long',
  $package_version               = 'installed',
  $package_name                  = $::squid3::params::package_name,
  $service_ensure                = 'running',
  $service_enable                = $::squid3::params::service_enable,
  $service_name                  = $::squid3::params::service_name,
) inherits ::squid3::params {

  $cache_dir_paths_1=regsubst($cache_dir,'([a-z]+ +)(.*)','\2')
  $cache_dir_paths=regsubst($cache_dir_paths_1,' .*','')
  #if we're wrong in the regex, this might thown a puppet error : Could not intern from text/pson
  file { $cache_dir_paths :
    ensure => directory,
    mode => '0644',
    owner => $user,
    group => $user,
    require => Package['squid3_package'],
  }
  
  $use_template = $template ? {
    'short' => 'squid3/squid.conf.short.erb',
    'long'  => 'squid3/squid.conf.long.erb',
    default => $template,
  }

  if ! empty($config_hash) and $use_template == 'long' {
    fail('$config_hash does not (yet) work with the "long" template!')
  }

  package { 'squid3_package':
    ensure => $package_version,
    name   => $package_name,
  }

  service { 'squid3_service':
    ensure    => $service_ensure,
    enable    => $service_enable,
    name      => $service_name,
   restart   => "service ${service_name} reload",
    path      => [ '/sbin', '/usr/sbin', '/usr/local/etc/rc.d' ],
    hasstatus => true,
    require   => Package['squid3_package'],
  }

  #the .puppet config file will have the same contents as the real config, and will be dumped by the customize script
  file { [$config_file,"${config_file}.puppet"]:
    require      => Package['squid3_package'],
    notify       => Service['squid3_service'],
    content => $variant ? { /frontier/ => template("squid3/${frontier_template_name}"), default => template("squid3/${template_name}") },
    mode => $variant ? { /frontier/ =>'0444', default => '0644'} ,
    validate_cmd => $variant ? { /frontier/ => "/bin/true" , default => "/usr/sbin/${service_name} -k parse -f %" },
    owner => $variant ? { /frontier/ => $user , default => 'root' },
  }

  if($variant == 'frontier') {
    #frontier is not in RHEL repos.
    include squid3::repository::frontier
    
    #prevent standard squid/frontier collision :
    package{['squid','squid3'] : 
      ensure=>absent,
      before=>Package['squid3_package']
    }
    
    #disable automatic customization "à la CERN"
    file { '/etc/squid/customize.sh': 
      content => template('squid3/customize.sh'),
      mode=>'0755',
      require=>Package['squid3_package'],
      before=> [Service['squid3_service'],File[$config_file]],
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
         notify=>Service['squid3_service'],
         require=>File[$config_file],
         before=>Service['squid3_service'],
         path => ['/usr/bin','/usr/sbin','/bin','/sbin',],
         logoutput => on_failure,
       }
    }
  }
}
