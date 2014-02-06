# Class: squid3::params
#
class squid3::params(
  $variant=squid #this can be frontier on RHEL.
) {

  $prefix=$variant ? { /frontier/ => 'frontier-', default => '' }
  case $::osfamily {
    'RedHat': {
      if $::operatingsystemrelease < 6 {
        $package_name = $variant ? { /frontier/ => 'frontier-squid', default => 'squid3' }
      } else {
        $package_name = "${prefix}squid"
      }
      $service_name = "${prefix}squid"
      $config_file = '/etc/squid/squid.conf'
      $log_directory = '/var/log/squid'
    }
    'Debian': {
      $package_name  = 'squid3'
      $service_name  = 'squid3'
      $config_file   = '/etc/squid3/squid.conf'
      $log_directory = '/var/log/squid3'
    }
    default: {
      $package_name = 'squid'
      $service_name = 'squid'
      $config_file = '/etc/squid/squid.conf'
      $log_directory = '/var/log/squid'
    }
  }
  $access_log      = [ "${log_directory}/access.log squid" ]
  $cache_log       = "${log_directory}/cache.log"
  $cache_store_log = "${log_directory}/store.log"

}

