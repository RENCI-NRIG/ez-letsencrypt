#!/usr/bin/env bash

### DEFAULT VALUES ###
rsa_key_size=4096
nginx_container_name='letsencrypt_nginx'
le_hostname=""
le_email=""
le_nginx=""
le_certsdir=$(pwd)/certsdir
le_webrootdir=$(pwd)/webrootdir
checkcert=false
dryrun=false
renew=false
selinux=false
verbose=false
num_args=$#
### DEFAULT VALUES ###

# display usage
usage() {
    cat <<EOF >&2
Usage: $0 -h <hostname> [<options>]

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
EOF
exit 1;
}

# execute openssl s_client and display issuer subject email and dates
openssl_check_cert() {
    echo | openssl s_client -servername $le_hostname -connect $le_hostname:443 2>/dev/null | \
    openssl x509 -noout -issuer -subject -dates
}

# execute openssl s_client and display pubkey
openssl_pubkey() {
    echo | openssl s_client -servername $le_hostname -connect $le_hostname:443 2>/dev/null | \
    openssl x509 -noout -pubkey
}

# generate http nginx conf for let's encrypt webroot challenge
generate_http_letsencrypt_conf() {
    OUTFILE=./letsencrypt.conf
    cat <<EOF > ${OUTFILE}
server {
    listen      80;
    listen [::]:80;
    server_name $le_hostname;
    location ^~ /.well-known {
        allow all;
        root /data/letsencrypt/;
    }
}
EOF
    case $verbose in
        (true)
            echo "[DEBUG] letsencrypt.conf file"
            cat $OUTFILE
            ;;
    esac
}

# generate http/https nginx conf for verifying let's encrypt cert
generate_https_letsencrypt_conf() {
    OUTFILE=./letsencrypt.conf
    cat <<EOF > ${OUTFILE}
server {
    listen      80;
    listen [::]:80;
    server_name $le_hostname;
    location / {
        rewrite ^ https://\$host\$request_uri? permanent;
    }
}

server {
    listen      443 ssl;
    listen [::]:443 ssl;
    server_name $le_hostname;
    ssl_certificate           /etc/letsencrypt/live/$le_hostname/fullchain.pem;
    ssl_certificate_key       /etc/letsencrypt/live/$le_hostname/privkey.pem;
    ssl_trusted_certificate   /etc/letsencrypt/live/$le_hostname/chain.pem;
    location / {
        root   /usr/share/nginx/html;
        index  index.html index.htm;
    }
}
EOF
    case $verbose in
        (true)
            echo "[DEBUG] letsencrypt.conf file"
            cat $OUTFILE
            ;;
    esac
}

# run nginx container exposing http port 80 only
run_http_nginx_container() {
    case $selinux in
    (true)
        docker run -d --name $nginx_container \
            --publish 80:80 \
            --volume $le_certsdir:/etc/letsencrypt:z,ro \
            --volume $le_webrootdir:/data/letsencrypt:z,rw \
            nginx:alpine >/dev/null 2>&1
        ;;
    (false )
        docker run -d --name $nginx_container \
            --publish 80:80 \
            --volume $le_certsdir:/etc/letsencrypt \
            --volume $le_webrootdir:/data/letsencrypt \
            nginx:alpine >/dev/null 2>&1
        ;;
    esac
}

# run nginx container exposing http/https ports 80 and 443
run_https_nginx_container() {
    case $selinux in
    (true)
        docker run -d --name $nginx_container \
            --publish 80:80 \
            --publish 443:443 \
            --volume $le_certsdir:/etc/letsencrypt:z,ro \
            --volume $le_webrootdir:/data/letsencrypt:z,rw \
            nginx:alpine >/dev/null 2>&1
        ;;
    (false )
        docker run -d --name $nginx_container \
            --publish 80:80 \
            --publish 443:443 \
            --volume $le_certsdir:/etc/letsencrypt \
            --volume $le_webrootdir:/data/letsencrypt \
            nginx:alpine >/dev/null 2>&1
        ;;
    esac
}

# remove nginx container and associate virtual volumes
remove_nginx_container() {
    docker stop $nginx_container >/dev/null 2>&1
    docker rm -fv $nginx_container >/dev/null 2>&1
}

# copy nginx conf file to running container
copy_server_conf() {
    IS_NGINX_UP=$(docker ps -f "name=${nginx_container}" -q)
    if [ ! -z "$IS_NGINX_UP" ]; then
        sleep 3s
        # letsencrypt.conf is copied using leading 0's to force it to be evaluated before default.conf on import
        docker cp ./letsencrypt.conf $nginx_container:/etc/nginx/conf.d/0000_letsencrypt.conf >/dev/null 2>&1
        docker exec $nginx_container /usr/sbin/nginx -t >/dev/null 2>&1
        docker exec $nginx_container /usr/sbin/nginx -s reload >/dev/null 2>&1
        rm -f ./letsencrypt.conf >/dev/null 2>&1
        sleep 3s
    else
        cat <<EOF
[ERROR] Nginx container $nginx_container is not running; Unable to copy letsencrypt.conf...
EOF
        exit 1;
    fi
}

# run certbot container
run_certbot_container() {
    # Set domain_args
    domain_args="-d "$le_hostname
    # Select appropriate email arg
    case $le_email in
        "") email_arg="--register-unsafely-without-email"; ;;
        *) email_arg="--email $le_email"; ;;
    esac
    # Select appropriate staging arg
    case $dryrun in
        true) staging_arg="--dry-run"; ;;
        *) staging_arg=""
    esac
    # Select appropriate run call
    case $selinux in
        (true)
            case $renew in
                (true)
                    docker run -it --rm \
                    -v $le_certsdir:/etc/letsencrypt:z,rw \
                    -v $le_webrootdir:/data/letsencrypt:z,rw \
                    certbot/certbot \
                    renew \
                    --webroot --webroot-path=/data/letsencrypt \
                    $staging_arg \
                    --rsa-key-size $rsa_key_size
                    ;;
                (false )
                    docker run -it --rm \
                    -v $le_certsdir:/etc/letsencrypt:z,rw \
                    -v $le_webrootdir:/data/letsencrypt:z,rw \
                    certbot/certbot \
                    certonly \
                    --webroot --webroot-path=/data/letsencrypt \
                    $staging_arg \
                    $email_arg \
                    $domain_args \
                    --rsa-key-size $rsa_key_size \
                    --agree-tos
                    ;;
            esac
            ;;
        (false)
            case $renew in
                (true)
                    docker run -it --rm \
                    -v $le_certsdir:/etc/letsencrypt \
                    -v $le_webrootdir:/data/letsencrypt \
                    certbot/certbot \
                    renew \
                    --webroot --webroot-path=/data/letsencrypt \
                    $staging_arg \
                    --rsa-key-size $rsa_key_size
                    ;;
                (false )
                    docker run -it --rm \
                    -v $le_certsdir:/etc/letsencrypt \
                    -v $le_webrootdir:/data/letsencrypt \
                    certbot/certbot \
                    certonly \
                    --webroot --webroot-path=/data/letsencrypt \
                    $staging_arg \
                    $email_arg \
                    $domain_args \
                    --rsa-key-size $rsa_key_size \
                    --agree-tos
                    ;;
            esac
            ;;
    esac
}

# transform long options to short ones
for arg in "$@"; do
  shift
  case "$arg" in
    "--hostname")   set -- "$@" "-h" ;;
    "-hostname")    echo "did you mean --hostname?"; usage ;;
    "--email")      set -- "$@" "-e" ;;
    "-email")       echo "did you mean --email?"; usage ;;
    "--nginx")      set -- "$@" "-n" ;;
    "-nginx")       echo "did you mean --nginx?"; usage ;;
    "--certsdir")   set -- "$@" "-c" ;;
    "-certsdir")    echo "did you mean --certsdir?"; usage ;;
    "--webrootdir") set -- "$@" "-w" ;;
    "-webrootdir")  echo "did you mean --webrootdir?"; usage ;;
    "--checkcert")  set -- "$@" "-k" ;;
    "-checkcert")   echo "did you mean --checkcert?"; usage ;;
    "--pubkey")     set -- "$@" "-p" ;;
    "-pubkey")      echo "did you mean --pubkey?"; usage ;;
    "--dryrun")     set -- "$@" "-d" ;;
    "-dryrun")      echo "did you mean --dryrun?"; usage ;;
    "--renew")      set -- "$@" "-r" ;;
    "-renew")       echo "did you mean --renew?"; usage ;;
    "--selinux")    set -- "$@" "-s" ;;
    "-selinux")     echo "did you mean --selinux?"; usage ;;
    "--usage")      set -- "$@" "-u" ;;
    "-usage")       echo "did you mean --usage?"; usage ;;
    "--verbose")    set -- "$@" "-v" ;;
    "-verbose")     echo "did you mean --verbose?"; usage ;;
    *)              set -- "$@" "$arg"
  esac
done

# parse user input for valid options
while getopts "h:e:n:c:w:kpdrsuv" o; do
    case "${o}" in
        h)
            le_hostname=${OPTARG}
            ;;
        e)
            le_email=${OPTARG}
            ;;
        n)
            le_nginx=${OPTARG}
            ;;
        c)
            le_certsdir=${OPTARG}
            ;;
        w)
            le_webrootdir=${OPTARG}
            ;;
        k)
            checkcert=true
            openssl_check_cert
            exit 0;
            ;;
        p)
            pubkey=true
            openssl_pubkey
            exit 0;
            ;;
        d)
            dryrun=true
            ;;
        r)
            renew=true
            ;;
        s)
            selinux=true
            ;;
        u)
            usage
            ;;
        v)
            verbose=true
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

### MAIN ###
case $verbose in
    (true)
        cat <<EOF
[DEBUG] variable settings
- hostname    = $le_hostname
- email       = $le_email
- nginx       = $le_nginx
- certsdir    = $le_certsdir
- webrootdir  = $le_webrootdir
- checkcert   = $checkcert
- pubkey      = $pubkey
- dryrun      = $dryrun
- renew       = $renew
- selinux     = $selinux
- verbose     = $verbose

EOF
        ;;
esac

# ensure a hostname is given
if [ -z "${le_hostname}" ]; then
    usage
fi

# set nginx_container name
if [ ! -z "$le_nginx" ]; then
    nginx_container=$le_nginx
else
    nginx_container=$nginx_container_name
fi

# generate http letsencrypt.conf
generate_http_letsencrypt_conf

# run http nginx if needed
if [ -z "$le_nginx" ]; then
    run_http_nginx_container
fi

# add letsencrypt.conf to nginx
copy_server_conf

# run the certbot container
run_certbot_container

# remove http nginx if needed
if [ -z "$le_nginx" ]; then
    remove_nginx_container
fi

# display --checkcert and --pubkey to user if this is the first time obtaining a certificate
case $dryrun in
    (false)
        case $renew in
            (false)
                # run https nginx if needed
                if [ -z "$le_nginx" ]; then
                    generate_https_letsencrypt_conf
                    run_https_nginx_container
                    copy_server_conf
                    echo "[INFO] Result of --checkcert"
                    openssl_check_cert
                    echo "[INFO] Result of --pubkey"
                    openssl_pubkey
                    # remove https nginx if needed
                    remove_nginx_container
                fi
                # inform user of nginx ssl configuration
                cat <<EOF
[INFO] Nginx ssl certificate configuration values (relative to nginx container: $nginx_container)
- ssl_certificate           /etc/letsencrypt/live/$le_hostname/fullchain.pem;
- ssl_certificate_key       /etc/letsencrypt/live/$le_hostname/privkey.pem;
- ssl_trusted_certificate   /etc/letsencrypt/live/$le_hostname/chain.pem;
EOF
                ;;
        esac
        ;;
esac

exit 0;
