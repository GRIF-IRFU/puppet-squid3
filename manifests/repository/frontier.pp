/**
 * This defines the frontier repository.
 * In cas you would have your own mirror and would like to disable this one, 
 * you can define a class that inherits this one and that will change the "enabled" property of Yumrepo['frontier']
 *   
 */
 class squid3::repository::frontier (
  $cost=1000,
  $priority=50, #this uses the yum priority plugin.
) {
  
  $gpgkey="RPM-GPG-KEY-CernFrontier"
  file {"/etc/pki/rpm-gpg/$gpgkey":
    source => "puppet:///modules/squid3/$gpgkey",
    ensure => present,
  }
  ~>
  exec { "gpgfile $gpgkey import":
    refreshonly => true,
    command =>"/bin/rpm --import /etc/pki/rpm-gpg/$gpgkey",
  }
 
  $reponame="frontier-squid-cern"
  yumrepo{ $reponame: 
    descr=>"Repository for frontier-squid",
    baseurl=>"http://frontier.cern.ch/dist/rpms/",
    enabled => 1, 
    gpgcheck => 1, 
    cost => $cost,
    protect => 1,
    priority=> $priority,
    gpgkey => "file:///etc/pki/rpm-gpg/${gpgkey}",
    metadata_expire => 5400,
  }
 
  #If there is a "purge" on the repos dir, make sure we're not purged :
  file {"/etc/yum.repos.d/${reponame}.repo":
    ensure  => present,
  } 
    
}
