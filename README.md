# EZ Let's Encrypt

A shell script to obtain and renew [Let's Encrypt](https://letsencrypt.org) certificates using Certbot's `--webroot` method of [certificate issuance](https://certbot.eff.org/docs/using.html#webroot).

## Table of Contents

- [About](#about)
- [Prerequisites](#prereq)
- [Usage](#usage)
- [Detailed Usage](#detusage)
- [Examples](#examples)
    - [Obtain certificate for new environment - no prior running web service](#new-no-nginx)
    - [Obtain certificate for preexisting environment - has prior running Nginx service](#new-yes-nginx)
    - [Renew certificate - no prior running web service](#renew-no-nginx)
    - [Renew certificate - has prior running Nginx service](#renew-yes-nginx)
    - [Convenience option `--checkcert`](#checkcert)
    - [Convenience option `--pubkey`](#pubkey)
- [References](#ref)

## <a name="about"></a>About

This purpose of this script is to make the process of obtaining and renewing Let's Encrypt certificates as easy as possible. To do this [Cerbot](https://certbot.eff.org/docs/index.html) is used in two ways:

- `certonly` mode - Obtain or renew a certificate, but do not install it
- `renew` mode - Renew all previously obtained certificates that are near expiry
- Certbot is meant to be run directly on a web server, normally by a system administrator. In most cases, running Certbot on your personal computer is not a useful option.

This script makes use of Certbot's `--webroot` directive which obtains a certificate by writing to the webroot directory of an already running web-server using the ACME HTTP-01 authentication challenge.

![Screen Shot 2021-09-23 at 5 20 40 PM](https://user-images.githubusercontent.com/5332509/134679027-f3cec176-9443-45b0-b586-063094fcf2cf.png)
<p style="text-align: center;">[Image 1: Let's Encrypt example certificate as seen in browser]</p>

## <a name="prereq"></a>Prerequisites

Before starting with EZ Let’s Encrypt, you need to:

- Have [Docker](https://docs.docker.com/get-docker/) installed on the host you wish to install the Let's Encrypt certificate on
- Own or control the registered domain name for the certificate. If you don’t have a registered domain name, you can use a domain name registrar, such as [GoDaddy](https://www.godaddy.com/domains/domain-name-search) or [dnsexit](https://www.dnsexit.com/)
- Create a DNS record that associates your domain name and your server’s public IP address

Now you can easily set up Let’s Encrypt SSL certificates with Nginx and Certbot using Docker.

## <a name="usage"></a>Usage

The `ez_letsencrypt.sh` script currently supports the following options.

```console
$ ./ez_letsencrypt.sh --usage
Usage: ./ez_letsencrypt.sh -h <hostname> [<options>]

    -h, --hostname <hostname>       hostname you are requesting the ssl certificate for
    -e, --email <email>             email to register with eff
    -n, --nginx <nginx_name>        use existing nginx container for host challenge
    -c, --certsdir <certs_dir>      directory on host to store let's encrypt ssl certificate
    -w, --webrootdir <webroot_dir>  directory on host to store webroot challenge files
    -k, --checkcert                 show certificate issuer, subject and dates for given hostname
    -p, --pubkey                    show certificate pubkey for given hostname
    -d, --dryrun                    test "renew" or "certonly" without saving any certificates to disk
    -r, --renew                     renew all previously obtained certificates that are near expiry
    -s, --selinux                   host is running centos with selinux enabled
    -u, --usage                     show this usage message and exit
    -v, --verbose                   verbose mode for debug output

```

## <a name="detusage"></a>Detailed Usage

### `-h`, `--hostname` `<hostname>`: hostname you are requesting the ssl certificate for

- **REQUIRED**: A hostname is required as the first parameter and defines the fully qualified domain name (FQDN) to obtain a certificate for
- If using the `--checkcert` or `--pubkey` options the hostname is the domain that is checked on port 443 by OpenSSL and can be any valid domain name
 

### `-e`, `--email` `<email>`: email to register with eff

- **OPTIONAL**: Email address that gets registered with EFF upon the generation of a new certificate and is used for important account notifications related to the issued certificate
- Email is only used during the generation of a new certificate and is not used in `--renew`, `--checkcert` or `--pubkey` calls

### `-n`, `--nginx` `<nginx_name>`: use existing nginx container for host challenge

- **OPTIONAL**: Use your preexisting Nginx container name instead of standing up a new one for the host challenge
- The preexisting Nginx container must also define the `certsdir` as a volume mount of the form: `<local_mount>:/etc/letsencrypt` so that the web-server can place the Let's Encrypt certificate files following the authentication challenge
- The preexisting Nginx container must also define the `webrootdir` as a volume mount of the form: `<local_mount>:/data/letsencrypt` so that the web-server receiving the challenge files can place them into the same volume mount that the Certbot uses to respond to the files
- Example snippet from `docker-compose.yaml`

    ```yaml
      nginx:
        image: nginx:latest
        container_name: nginx
        ports:
          - '80:80'
          - '443:443'
        volumes:
          - ${NGINX_DEFAULT_CONF:-./nginx/default.conf}:/etc/nginx/conf.d/default.conf
          - ${NGINX_LOGS:-./logs/nginx}:/var/log/nginx
          - /root/certs:/etc/letsencrypt                # --certsdir
          - /home/jenkins/acme_files:/data/letsencrypt  # --webrootdir
        restart: always
    ```
    
    These updates generally require a restart of the Nginx container if it had already been running.
    
    ```console
    $ docker-compose stop nginx && docker-compose rm -fv nginx && docker-compose up -d nginx
    Stopping nginx ... done
    Going to remove nginx
    Removing nginx ... done
    Creating nginx ... done
    ```

### `-c`, `--certsdir` `<certs_dir>`: directory on host to store let's encrypt ssl certificate

- **OPTIONAL**: Defines where to place the Let's Encrypt certificate files following the authentication challenge
- Defined as an Nginx container volume mount: `<local_mount>:/etc/letsencrypt`
- Default value for local mount is: `$(pwd)/certsdir`

### `-w`, `--webrootdir` `<webroot_dir>`: directory on host to store webroot challenge files

- **OPTIONAL**: Defines where to place files in a server's webroot folder for authentication challenge
- Defined as an Nginx container volume mount: `<local_mount>:/data/letsencrypt`
- Default value for local mount is: `$(pwd)/webrootdir`

### `-k`, `--checkcert`: show certificate issuer, subject and dates for given hostname

- **OPTIONAL**: Using the provided hostname to define a domain, an OpenSSL s_client call is issued to port 443 of the domain and if successful will return `issuer`, `subject` and `dates` information for the certificate being used by that domain

### `-p`, `--pubkey`: show certificate pubkey for given hostname

- **OPTIONAL**: Using the provided hostname to define a domain, an OpenSSL s_client call is issued to port 443 of the domain and if successful will return `pubkey` information for the certificate being used by that domain

### `-d`, `--dryrun`: test "renew" or "certonly" without saving any certificates to disk

- **OPTIONAL**: A full authentication challenge is run for obtaining or renewing a certificate but no new files are saved to disk. This is a good option to use while initially configuring your system.

### `-r`, `--renew`: renew all previously obtained certificates that are near expiry

- **OPTIONAL**: Attempt to renew all previously obtained certificates that are near expiry
- Default behavior is `certonly` which attempts to get a new certificate unless the `--renew` flag is set

### `-s`, `--selinux`: host is running centos with selinux enabled

- **OPTIONAL**: Use this option if the host has enabled Security-Enhanced Linux (SELinux) - related to RHEL and CentOS

### `-u`, `--usage`: show this usage message and exit

- **OPTIONAL**: show the usage message

### `-v`, `--verbose`: verbose mode for debug output

- **OPTIONAL**: verbose mode for additional debug related output.

## <a name="examples"></a>Examples

### <a name="new-no-nginx"></a>Obtain certificate for new environment - no prior running web service

**Goal**: obtain a new certificate for `aerpaw-dev.renci.org`

- Hostname: `aerpaw-dev.renci.org`
- Email to register: `michael.j.stealey@gmail.com`
- Store SSL cert at: `/root/certs`
- Store webroot challenge files at: `$(pwd)/acme_files`


Test run with `--dryrun`:

```console
$ ./ez_letsencrypt.sh --hostname aerpaw-dev.renci.org \
>     --email michael.j.stealey@gmail.com \
>     --certsdir /root/certs \
>     --webrootdir $(pwd)/acme_files \
>     --dryrun
Saving debug log to /var/log/letsencrypt/letsencrypt.log
Account registered.
Simulating a certificate request for aerpaw-dev.renci.org
The dry run was successful.
```

Obtain new certificate (Answer the **Y(es)/N(o)** question when prompted):

```console
$ ./ez_letsencrypt.sh --hostname aerpaw-dev.renci.org \
>     --email michael.j.stealey@gmail.com \
>     --certsdir /root/certs \
>     --webrootdir $(pwd)/acme_files
Saving debug log to /var/log/letsencrypt/letsencrypt.log

- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Would you be willing, once your first certificate is successfully issued, to
share your email address with the Electronic Frontier Foundation, a founding
partner of the Let's Encrypt project and the non-profit organization that
develops Certbot? We'd like to send you email about our work encrypting the web,
EFF news, campaigns, and ways to support digital freedom.
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
(Y)es/(N)o: Y
Account registered.
Requesting a certificate for aerpaw-dev.renci.org

Successfully received certificate.
Certificate is saved at: /etc/letsencrypt/live/aerpaw-dev.renci.org/fullchain.pem
Key is saved at:         /etc/letsencrypt/live/aerpaw-dev.renci.org/privkey.pem
This certificate expires on 2021-12-22.
These files will be updated when the certificate renews.

NEXT STEPS:
- The certificate will need to be renewed before it expires. Certbot can automatically renew the certificate in the background, but you may need to take steps to enable that functionality. See https://certbot.org/renewal-setup for instructions.

- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
If you like Certbot, please consider supporting our work by:
 * Donating to ISRG / Let's Encrypt:   https://letsencrypt.org/donate
 * Donating to EFF:                    https://eff.org/donate-le
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
[INFO] Result of --checkcert
issuer= /C=US/O=Let's Encrypt/CN=R3
subject= /CN=aerpaw-dev.renci.org
notBefore=Sep 23 19:15:35 2021 GMT
notAfter=Dec 22 19:15:34 2021 GMT
[INFO] Result of --pubkey
-----BEGIN PUBLIC KEY-----
MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAoE5e4VeAXcySo90B4wkE
9yziHPVqiyRo1iIwZV+jwaLkpDCUTlpqYYPTUFzCGAzFOIuSf7qO6hkGpneLm/R7
eb9wNG8CFYsNAY8z+xYKWIhWghe5JIzV4sUKKUouwwN8fu9bvaBI4LvUJwcQ0wrJ
xd0QsjNe/3WB+eUmqaU8nuHB9nMCJtnzf8A5XmD0CmhYAwqTL8qZPPijWbSW8fhA
4YlrqtlMrPj6tp2mdQakewytyMGIf0GrobAw/gwltyZxoovN+bZo6W5aA0Au5kxa
KvJ41Me1oFXpHML8XfD+FhXNQgohEePJmL+oGGZqMHjhIBCbzorTjc9iJmcD5HKR
JkXTurJfphDyXLCT5JSCMLH2JYA1Z+qCGUv01QHD5I91utDr+kNgx2XieP2Zs20s
xNvLemx2SAvevp9Qa0GFubv7qAdJDBQqlqU1wZUcyBy+k7dUgWuMZf3DpDAUFNYi
ltMRlo+kgbaYmpzz2YMqmVIwCzC7cC5I3/EbRKfc0d/rJ4DdMdbLC4Zb6hhJ+atU
DY/ogRvTNAvSTX5e3fYfW6ZgQYhHiHLLPATUuuRQe+amrtTKzEeWHZACRwtkZf8v
RV6GAAvZ8RqmDqno0p/9Unt+laEZXQB3Jl3rj1AuVNsVfaImlwj05AWZBl81nj/0
2uqU908LS68zpSPDDWSYLpsCAwEAAQ==
-----END PUBLIC KEY-----
[INFO] Nginx ssl certificate configuration values (relative to nginx container: nginx-for-some-app)
- ssl_certificate           /etc/letsencrypt/live/aerpaw-dev.renci.org/fullchain.pem;
- ssl_certificate_key       /etc/letsencrypt/live/aerpaw-dev.renci.org/privkey.pem;
- ssl_trusted_certificate   /etc/letsencrypt/live/aerpaw-dev.renci.org/chain.pem;
```

Note the Nginx configuration paths for the newly generated SSL Certificate relative to the Nginx container.

```console
[INFO] Nginx ssl certificate configuration values (relative to nginx container: nginx-for-some-app)
- ssl_certificate           /etc/letsencrypt/live/aerpaw-dev.renci.org/fullchain.pem;
- ssl_certificate_key       /etc/letsencrypt/live/aerpaw-dev.renci.org/privkey.pem;
- ssl_trusted_certificate   /etc/letsencrypt/live/aerpaw-dev.renci.org/chain.pem;
```

Using `default.conf` as an example, the above values would be used for the `ssl_certificate` entries.

```nginx
server {
  listen 80;
  server_name aerpaw-dev.renci.org;
  return 301 https://$host$request_uri;
}

server {

    listen 443 ssl;
    server_name aerpaw-dev.renci.org;

    # NEW Let's Encrypt Certificate 
    ssl_certificate           /etc/letsencrypt/live/aerpaw-dev.renci.org/fullchain.pem;
    ssl_certificate_key       /etc/letsencrypt/live/aerpaw-dev.renci.org/privkey.pem;
    ssl_trusted_certificate   /etc/letsencrypt/live/aerpaw-dev.renci.org/chain.pem;

    location / {
        return 301 https://aerpaw-dev.renci.org/jenkins;
    }
    ...
}
```

After answering **Y(es)/N(o)** regarding registration a new certificate will be issued and placed in the `certsdir`. In this example that is the `/root/certs` directory:

```console
# tree /root/certs
/root/certs
├── accounts
│   └── acme-v02.api.letsencrypt.org
│       └── directory
│           └── 39f7283da445b5c099132823a6c2f5d3
│               ├── meta.json
│               ├── private_key.json
│               └── regr.json
├── archive
│   └── aerpaw-dev.renci.org
│       ├── cert1.pem
│       ├── chain1.pem
│       ├── fullchain1.pem
│       └── privkey1.pem
├── csr
│   └── 0000_csr-certbot.pem
├── keys
│   └── 0000_key-certbot.pem
├── live
│   ├── aerpaw-dev.renci.org
│   │   ├── cert.pem -> ../../archive/aerpaw-dev.renci.org/cert1.pem
│   │   ├── chain.pem -> ../../archive/aerpaw-dev.renci.org/chain1.pem
│   │   ├── fullchain.pem -> ../../archive/aerpaw-dev.renci.org/fullchain1.pem
│   │   ├── privkey.pem -> ../../archive/aerpaw-dev.renci.org/privkey1.pem
│   │   └── README
│   └── README
├── renewal
│   └── aerpaw-dev.renci.org.conf
└── renewal-hooks
    ├── deploy
    ├── post
    └── pre

15 directories, 16 files
```

The new certificate files can be found under the `live/$(hostname)/` directory as symbolic links that reference versioned archive files. The versioned archive files are the actual files that are updated when the certificates are renewed and the symbolic links are regenerated.

### <a name="new-yes-nginx"></a>Obtain certificate for preexisting environment - has prior running Nginx service

**Goal**: obtain a new certificate for `aerpaw-dev.renci.org` which is already running an Nginx web-server on port 80

This is often the case of a newly developed service that runs on port 80, but now you've been asked to add an SSL certificate. We need to get the name of the running Nginx container and introduce the mount points for both the `certsdir` and `webrootdir` values to the running container.

```console
$ docker ps --format '{{.Names}} | {{.Image}} | {{.Ports}}' | grep nginx
nginx-for-some-app | nginx:alpine | 0.0.0.0:80->80/tcp, :::80->80/tcp
```

- Hostname: `aerpaw-dev.renci.org`
- Email to register: `michael.j.stealey@gmail.com`
- Nginx container name: `nginx-for-some-app`
- Store SSL cert at: `/root/certs`
- Store webroot challenge files at: `/home/jenkins/acme_files`

Add the `--certsdir` and `--webroot` volume mounts to your deployed Nginx container (example using `docker-compose.yaml`)

```yaml
  nginx-for-some-app:
    image: nginx:latest
    container_name: nginx-for-some-app
    ports:
      - '80:80'
      - '443:443'
    volumes:
      - ${NGINX_DEFAULT_CONF:-./nginx/default.conf}:/etc/nginx/conf.d/default.conf
      - ${NGINX_LOGS:-./logs/nginx}:/var/log/nginx
      - /root/certs:/etc/letsencrypt                # --certsdir
      - /home/jenkins/acme_files:/data/letsencrypt  # --webrootdir
    restart: always
```

Volume mount updates generally require a restart of the Nginx container to be recognized.
    
```console
$ docker-compose stop nginx-for-some-app && docker-compose rm -fv nginx-for-some-app && docker-compose up -d nginx-for-some-app
Stopping nginx-for-some-app ... done
Going to remove nginx-for-some-app
Removing nginx-for-some-app ... done
Creating nginx-for-some-app ... done
```

Test run with `--dryrun`:

```console
$ ./ez_letsencrypt.sh --hostname aerpaw-dev.renci.org \
>     --email michael.j.stealey@gmail.com \
>     --nginx nginx-for-some-app \
>     --certsdir /root/certs \
>     --webrootdir /home/jenkins/acme_files \
>     --dryrun
Saving debug log to /var/log/letsencrypt/letsencrypt.log
Simulating a certificate request for aerpaw-dev.renci.org
The dry run was successful.
```

Obtain new certificate (Answer the **Y(es)/N(o)** question when prompted):


```console
$ ./ez_letsencrypt.sh --hostname aerpaw-dev.renci.org \
>     --email michael.j.stealey@gmail.com \
>     --nginx nginx-for-some-app \
>     --certsdir /root/certs \
>     --webrootdir /home/jenkins/acme_files
Saving debug log to /var/log/letsencrypt/letsencrypt.log

- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Would you be willing, once your first certificate is successfully issued, to
share your email address with the Electronic Frontier Foundation, a founding
partner of the Let's Encrypt project and the non-profit organization that
develops Certbot? We'd like to send you email about our work encrypting the web,
EFF news, campaigns, and ways to support digital freedom.
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
(Y)es/(N)o: Y
Account registered.
Requesting a certificate for aerpaw-dev.renci.org

Successfully received certificate.
Certificate is saved at: /etc/letsencrypt/live/aerpaw-dev.renci.org/fullchain.pem
Key is saved at:         /etc/letsencrypt/live/aerpaw-dev.renci.org/privkey.pem
This certificate expires on 2021-12-22.
These files will be updated when the certificate renews.

NEXT STEPS:
- The certificate will need to be renewed before it expires. Certbot can automatically renew the certificate in the background, but you may need to take steps to enable that functionality. See https://certbot.org/renewal-setup for instructions.
We were unable to subscribe you the EFF mailing list because your e-mail address appears to be invalid. You can try again later by visiting https://act.eff.org.

- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
If you like Certbot, please consider supporting our work by:
 * Donating to ISRG / Let's Encrypt:   https://letsencrypt.org/donate
 * Donating to EFF:                    https://eff.org/donate-le
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
[INFO] Nginx ssl certificate configuration values (relative to nginx container: nginx-for-some-app)
- ssl_certificate           /etc/letsencrypt/live/aerpaw-dev.renci.org/fullchain.pem;
- ssl_certificate_key       /etc/letsencrypt/live/aerpaw-dev.renci.org/privkey.pem;
- ssl_trusted_certificate   /etc/letsencrypt/live/aerpaw-dev.renci.org/chain.pem;
```

Note the Nginx configuration paths for the newly generated SSL Certificate relative to the Nginx container.

```console
[INFO] Nginx ssl certificate configuration values (relative to nginx container: nginx-for-some-app)
- ssl_certificate           /etc/letsencrypt/live/aerpaw-dev.renci.org/fullchain.pem;
- ssl_certificate_key       /etc/letsencrypt/live/aerpaw-dev.renci.org/privkey.pem;
- ssl_trusted_certificate   /etc/letsencrypt/live/aerpaw-dev.renci.org/chain.pem;
```

Using `default.conf` as an example, the above values would replace any prior `ssl_certificate` entries.

```nginx
server {
  listen 80;
  server_name aerpaw-dev.renci.org;
  return 301 https://$host$request_uri;
}

server {

    listen 443 ssl;
    server_name aerpaw-dev.renci.org;

    # NEW Let's Encrypt Certificate 
    ssl_certificate           /etc/letsencrypt/live/aerpaw-dev.renci.org/fullchain.pem;
    ssl_certificate_key       /etc/letsencrypt/live/aerpaw-dev.renci.org/privkey.pem;
    ssl_trusted_certificate   /etc/letsencrypt/live/aerpaw-dev.renci.org/chain.pem;

    # Prior SSL Certificate - no longer valid
    #ssl_certificate /etc/nginx/ssl/server.crt;
    #ssl_certificate_key /etc/nginx/ssl/server.key;

    location / {
        return 301 https://aerpaw-dev.renci.org/jenkins;
    }
    ...
}
```

Updates generally require a restart of the Nginx container to be recognized.
    
```console
$ docker-compose stop nginx-for-some-app && docker-compose rm -fv nginx-for-some-app && docker-compose up -d nginx-for-some-app
Stopping nginx-for-some-app ... done
Going to remove nginx-for-some-app
Removing nginx-for-some-app ... done
Creating nginx-for-some-app ... done
```

After answering **Y(es)/N(o)** regarding registration a new certificate will be issued and placed in the `certsdir`. In this example that is the `/root/certs` directory:

```console
# tree /root/certs
/root/certs
├── accounts
│   ├── acme-staging-v02.api.letsencrypt.org
│   │   └── directory
│   │       └── 6b14c906632f088508feb2ce4eb5406b
│   │           ├── meta.json
│   │           ├── private_key.json
│   │           └── regr.json
│   └── acme-v02.api.letsencrypt.org
│       └── directory
│           └── 306064794f85b75539fa55e26e8baa2e
│               ├── meta.json
│               ├── private_key.json
│               └── regr.json
├── archive
│   └── aerpaw-dev.renci.org
│       ├── cert1.pem
│       ├── chain1.pem
│       ├── fullchain1.pem
│       └── privkey1.pem
├── csr
│   └── 0000_csr-certbot.pem
├── keys
│   └── 0000_key-certbot.pem
├── live
│   ├── aerpaw-dev.renci.org
│   │   ├── cert.pem -> ../../archive/aerpaw-dev.renci.org/cert1.pem
│   │   ├── chain.pem -> ../../archive/aerpaw-dev.renci.org/chain1.pem
│   │   ├── fullchain.pem -> ../../archive/aerpaw-dev.renci.org/fullchain1.pem
│   │   ├── privkey.pem -> ../../archive/aerpaw-dev.renci.org/privkey1.pem
│   │   └── README
│   └── README
├── renewal
│   └── aerpaw-dev.renci.org.conf
└── renewal-hooks
    ├── deploy
    ├── post
    └── pre

18 directories, 19 files
```

The new certificate files can be found under the `live/$(hostname)/` directory as symbolic links that reference versioned archive files. The versioned archive files are the actual files that are updated when the certificates are renewed and the symbolic links are regenerated.

### <a name="renew-no-nginx"></a>Renew certificate - no prior running web service

**Goal**: renew an existing certificate for `aerpaw-dev.renci.org` which isn't presently running a web-server on either port 80 or port 443

This situation can arise when a user does not want to embed the `.well-known` location stanza into their Nginx configuration for port 80 and would prefer to momentarily bring their service down in order to renew their Let's Encrypt certificate.

- Hostname: `aerpaw-dev.renci.org`
- Store certs at: `/root/certs`
- Store webroot challenge files at: `$(pwd)/acme_files`

Test renew with `--dryrun`:

```console
$ ./ez_letsencrypt.sh --hostname aerpaw-dev.renci.org \
>     --renew \
>     --certsdir /root/certs \
>     --webrootdir $(pwd)/acme_files \
>     --dryrun
Saving debug log to /var/log/letsencrypt/letsencrypt.log

- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Processing /etc/letsencrypt/renewal/aerpaw-dev.renci.org.conf
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Simulating renewal of an existing certificate for aerpaw-dev.renci.org

- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Congratulations, all simulated renewals succeeded:
  /etc/letsencrypt/live/aerpaw-dev.renci.org/fullchain.pem (success)
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
```

Renew certificate:

```console
$ ./ez_letsencrypt.sh --hostname aerpaw-dev.renci.org \
>     --renew \
>     --certsdir /root/certs \
>     --webrootdir $(pwd)/acme_files
Saving debug log to /var/log/letsencrypt/letsencrypt.log

- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Processing /etc/letsencrypt/renewal/aerpaw-dev.renci.org.conf
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Certificate not yet due for renewal

- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
The following certificates are not due for renewal yet:
  /etc/letsencrypt/live/aerpaw-dev.renci.org/fullchain.pem expires on 2021-12-22 (skipped)
No renewals were attempted.
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
```

Since the certificate is still within its window of validity it was not renewed at this time.

### <a name="renew-yes-nginx"></a>Renew certificate - has prior running Nginx service

**Goal**: renew an existing certificate for `aerpaw-dev.renci.org` which is already running an Nginx web-server on port 80 and 443

Since the running service already uses Let's Encrypt certificate we need to get the name of the running Nginx container and verify the mount points for both the `certsdir` and `webrootdir` values.

```console
$ docker ps --format '{{.Names}} | {{.Image}} | {{.Ports}}' | grep nginx
nginx-for-some-app | nginx:alpine | 0.0.0.0:80->80/tcp, :::80->80/tcp, 0.0.0.0:443->443/tcp, :::443->443/tcp
```

- Hostname: `aerpaw-dev.renci.org`
- Nginx container name: `nginx-for-some-app`
- Existing certs at: `/root/certs`
- Existing webroot challenge files at: `$(pwd)/acme_files`

Test run with `--dryrun`:

```console
$ ./ez_letsencrypt.sh --hostname aerpaw-dev.renci.org \
>     --renew \
>     --nginx nginx-for-some-app \
>     --certsdir /root/certs \
>     --webrootdir $(pwd)/acme_files \
>     --dryrun
Saving debug log to /var/log/letsencrypt/letsencrypt.log

- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Processing /etc/letsencrypt/renewal/aerpaw-dev.renci.org.conf
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Simulating renewal of an existing certificate for aerpaw-dev.renci.org

- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Congratulations, all simulated renewals succeeded:
  /etc/letsencrypt/live/aerpaw-dev.renci.org/fullchain.pem (success)
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
```

Renew certificate:

```console
$ ./ez_letsencrypt.sh --hostname aerpaw-dev.renci.org \
>     --renew \
>     --nginx nginx-for-some-app \
>     --certsdir /root/certs \
>     --webrootdir $(pwd)/acme_files
Saving debug log to /var/log/letsencrypt/letsencrypt.log

- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Processing /etc/letsencrypt/renewal/aerpaw-dev.renci.org.conf
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Certificate not yet due for renewal

- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
The following certificates are not due for renewal yet:
  /etc/letsencrypt/live/aerpaw-dev.renci.org/fullchain.pem expires on 2021-12-22 (skipped)
No renewals were attempted.
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
```

Since the certificate is still within its window of validity it was not renewed at this time.

**NOTE about port 80** If the Nginx configuration automatically routes all traffic from port 80 to port 443 then we need to add a stanza to the existing configuration that allows the certificate challenge to take place.

Place the following `.well-known` location block inside the port 80 server definition prior to the https redirect.

```nginx
location ^~ /.well-known {
    allow all;
    root /data/letsencrypt/;
}
```

An indicator of this would be a failed renew dry-run attempt that looked similar to this:

```console
$ ./ez_letsencrypt.sh --hostname aerpaw-dev.renci.org \
>     --renew \
>     --nginx nginx-for-some-app \
>     --certsdir /root/certs \
>     --webrootdir $(pwd)/acme_files \
>     --dryrun
Saving debug log to /var/log/letsencrypt/letsencrypt.log

- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Processing /etc/letsencrypt/renewal/aerpaw-dev.renci.org.conf
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Simulating renewal of an existing certificate for aerpaw-dev.renci.org

Certbot failed to authenticate some domains (authenticator: webroot). The Certificate Authority reported these problems:
  Domain: aerpaw-dev.renci.org
  Type:   connection
  Detail: Fetching http://aerpaw-dev.renci.org/.well-known/acme-challenge/YE9yRLmkOeRxo4ejeClKTye_a_jw5xmMKYwVqpwEvec: Error getting validation data

Hint: The Certificate Authority failed to download the temporary challenge files created by Certbot. Ensure that the listed domains serve their content from the provided --webroot-path/-w and that files created there can be downloaded from the internet.

Failed to renew certificate aerpaw-dev.renci.org with error: Some challenges have failed.

- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
All simulated renewals failed. The following certificates could not be renewed:
  /etc/letsencrypt/live/aerpaw-dev.renci.org/fullchain.pem (failure)
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
1 renew failure(s), 0 parse failure(s)
Ask for help or search for solutions at https://community.letsencrypt.org. See the logfile /var/log/letsencrypt/letsencrypt.log or re-run Certbot with -v for more details.
```

Adding the aforementioned `.well-known` location block should resolve the issue.


### <a name="checkcert"></a>Convenience option `--checkcert`

**Goal**: retrieve certificate information for `aerpaw-dev.renci.org` which is already running an Nginx web-server on port 443

- Hostname: `aerpaw-dev.renci.org`

```console
$ ./ez_letsencrypt.sh --hostname aerpaw-dev.renci.org --checkcert
issuer= /C=US/O=Let's Encrypt/CN=R3
subject= /CN=aerpaw-dev.renci.org
notBefore=Sep 23 19:15:35 2021 GMT
notAfter=Dec 22 19:15:34 2021 GMT
```

The `--checkcert` command can be run against any valid domain, e.g. [github.com]()

```console
$ ./ez_letsencrypt.sh --hostname github.com --checkcert
issuer= /C=US/O=DigiCert, Inc./CN=DigiCert High Assurance TLS Hybrid ECC SHA256 2020 CA1
subject= /C=US/ST=California/L=San Francisco/O=GitHub, Inc./CN=github.com
notBefore=Mar 25 00:00:00 2021 GMT
notAfter=Mar 30 23:59:59 2022 GMT
```

### <a name="pubkey"></a>Convenience option `--pubkey`

**Goal**: retrieve pubkey information for `aerpaw-dev.renci.org` which is already running an Nginx web-server on port 443

- Hostname: `aerpaw-dev.renci.org`

```console
$ ./ez_letsencrypt.sh --hostname aerpaw-dev.renci.org --pubkey
-----BEGIN PUBLIC KEY-----
MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAoE5e4VeAXcySo90B4wkE
9yziHPVqiyRo1iIwZV+jwaLkpDCUTlpqYYPTUFzCGAzFOIuSf7qO6hkGpneLm/R7
eb9wNG8CFYsNAY8z+xYKWIhWghe5JIzV4sUKKUouwwN8fu9bvaBI4LvUJwcQ0wrJ
xd0QsjNe/3WB+eUmqaU8nuHB9nMCJtnzf8A5XmD0CmhYAwqTL8qZPPijWbSW8fhA
4YlrqtlMrPj6tp2mdQakewytyMGIf0GrobAw/gwltyZxoovN+bZo6W5aA0Au5kxa
KvJ41Me1oFXpHML8XfD+FhXNQgohEePJmL+oGGZqMHjhIBCbzorTjc9iJmcD5HKR
JkXTurJfphDyXLCT5JSCMLH2JYA1Z+qCGUv01QHD5I91utDr+kNgx2XieP2Zs20s
xNvLemx2SAvevp9Qa0GFubv7qAdJDBQqlqU1wZUcyBy+k7dUgWuMZf3DpDAUFNYi
ltMRlo+kgbaYmpzz2YMqmVIwCzC7cC5I3/EbRKfc0d/rJ4DdMdbLC4Zb6hhJ+atU
DY/ogRvTNAvSTX5e3fYfW6ZgQYhHiHLLPATUuuRQe+amrtTKzEeWHZACRwtkZf8v
RV6GAAvZ8RqmDqno0p/9Unt+laEZXQB3Jl3rj1AuVNsVfaImlwj05AWZBl81nj/0
2uqU908LS68zpSPDDWSYLpsCAwEAAQ==
-----END PUBLIC KEY-----
```

The `--pubkey` command can be run against any valid domain, e.g. [github.com]()

```console
$ ./ez_letsencrypt.sh --hostname github.com --pubkey
-----BEGIN PUBLIC KEY-----
MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAErfb3dbHTSVQKXRBxvdwlBksiHKIj
Tp+h/rnQjL05vAwjx8+RppBa2EWrAxO+wSN6ucTInUf2luC5dmtQNmb3DQ==
-----END PUBLIC KEY-----
```

## <a name="ref"></a>Reference

- Let's Encrypt: [https://letsencrypt.org](https://letsencrypt.org)
- Certbot commands: [https://certbot.eff.org/docs/using.html#certbot-commands](https://certbot.eff.org/docs/using.html#certbot-commands)
- Docker: [https://www.docker.com](https://www.docker.com)
- Nginx: [https://www.nginx.com](https://www.nginx.com)
- OpenSSL s_client: [https://www.openssl.org/docs/man1.0.2/man1/openssl-s_client.html](https://www.openssl.org/docs/man1.0.2/man1/openssl-s_client.html)

