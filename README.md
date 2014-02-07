# puppet-squid3

## Overview

Install, enable and configure a Squid 3 http proxy server with its main
configuration file options.

* `squid3` : Main class for the Squid 3 http proxy server.

This module has been modified by IRFU in order to add more parameters, and to be able to setup a CERN frontier squid server on RHEL.
It also includes the necessary yum repo, and allows for choosing the number of parrallel threads frontier will run with.

## Examples

Basic memory caching proxy server :

    include squid3

Non-caching multi-homed proxy server :

    class { 'squid3':
      acl => [
        'de myip 192.168.1.1',
        'fr myip 192.168.1.2',
        'office src 10.0.0.0/24',
      ],
      http_access => [
        'allow office',
      ],
      cache => [ 'deny all' ],
      via => 'off',
      tcp_outgoing_address => [
        '192.168.1.1 country_de',
        '192.168.1.2 country_fr',
      ],
      server_persistent_connections => 'off',
    }

