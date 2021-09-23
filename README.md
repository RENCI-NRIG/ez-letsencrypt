# EZ Let's Encrypt

A shell script to obtain and renew [Let's Encrypt](https://letsencrypt.org) certificates using the `--webroot` method of [certificate issuance](https://certbot.eff.org/docs/using.html#webroot).

## Prerequisites

Before starting with EZ Let’s Encrypt, you need to:

- Have [Docker](https://docs.docker.com/get-docker/) installed on the host you wish to install the Let's Encrypt certificate on
- Own or control the registered domain name for the certificate. If you don’t have a registered domain name, you can use a domain name registrar, such as [GoDaddy](https://www.godaddy.com/domains/domain-name-search) or [dnsexit](https://www.dnsexit.com/)
- Create a DNS record that associates your domain name and your server’s public IP address

Now you can easily set up Let’s Encrypt SSL certificates with Nginx and Certbot using Docker.

## Usage

```console
$ ./ez_letsencrypt.sh --usage
Usage: ./ez_letsencrypt.sh -h <hostname> [<options>]

    -h, --hostname <hostname>       hostname you are requesting the ssl certificate for
    -e, --email <email>             email to register with eff
    -n, --nginx <nginx_name>        use existing nginx container for host challenge
    -c, --certsdir <certs_dir>      directory on host to store let's encrypt ssl certificate
    -w, --webrootdir <webroot_dir>  directory on host to store webroot challenge files
    -k, --checkcert                 show certificate issuer, subject, email and dates for given hostname
    -p, --pubkey                    show certificate pubkey for given hostname
    -d, --dryrun                    test "renew" or "certonly" without saving any certificates to disk
    -r, --renew                     renew all previously obtained certificates that are near expiry
    -s, --selinux                   host is running centos with selinux enabled
    -u, --usage                     show this usage message and exit
    -v, --verbose                   verbose mode for debug output

```

## Detailed Usage

TODO: detailed usage

### `-h`, `--hostname` `<hostname>`: hostname you are requesting the ssl certificate for

### `-e`, `--email` `<email>`: email to register with eff

### `-n`, `--nginx` `<nginx_name>`: use existing nginx container for host challenge

### `-c`, `--certsdir` `<certs_dir>`: directory on host to store let's encrypt ssl certificate

### `-w`, `--webrootdir` `<webroot_dir>`: directory on host to store webroot challenge files

### `-k`, `--checkcert`: show certificate issuer, subject, email and dates for given hostname

### `-p`, `--pubkey`: show certificate pubkey for given hostname

### `-d`, `--dryrun`: test "renew" or "certonly" without saving any certificates to disk

### `-r`, `--renew`: renew all previously obtained certificates that are near expiry

### `-s`, `--selinux`: host is running centos with selinux enabled

### `-u`, `--usage`: show this usage message and exit

### `-v`, `--verbose`: verbose mode for debug output

## Examples

TODO: examples

### New certificate for brand new environment

### New certificate for preexisting Nginx environment

### Renew certificate for new environment

### Renew certificate for preexisting Nginx environment

### Convenience option `--checkcert`

### Convenience option `--pubkey`


## Reference

- Let's Encrypt: [https://letsencrypt.org](https://letsencrypt.org)
- Certbot commands: [https://certbot.eff.org/docs/using.html#certbot-commands](https://certbot.eff.org/docs/using.html#certbot-commands)
- Docker: [https://www.docker.com](https://www.docker.com)
- Nginx: [https://www.nginx.com](https://www.nginx.com)
- OpenSSL s_client: [https://www.openssl.org/docs/man1.0.2/man1/openssl-s_client.html](https://www.openssl.org/docs/man1.0.2/man1/openssl-s_client.html)

