#!/bin/sh

# ENV DOMAIN=example.com

echo "#DOMAIN: ${DOMAIN}"
echo '=================================================='
echo

# MKDIR Init
mkdir -p /etc/ssl/caddy /etc/caddy /data/gitea /var/tmp

# Gitea Init
[ -f /data/gitea/app.ini ] || cat << EOF > /data/gitea/app.ini
[server]
HTTP_PORT        = 8080
DOMAIN           = ${DOMAIN}
ROOT_URL         = https://${DOMAIN}/
DISABLE_SSH      = true
EOF
/usr/bin/gitea web -c /data/gitea/app.ini &

# Caddy Init
cp 404.html /var/tmp/
cat << EOF > /etc/caddy/Caddyfile
:80 {
  redir {
    if {path} not /404.html
    / /404.html
  }
}

${DOMAIN} {
  tls ssl@${DOMAIN}
  timeouts 30s
  gzip
  proxy /ws-conn http://localhost:8888 {
    websocket
  }

$( for i in `seq 0 9`; do
cat << FOO
  proxy /ws-conn${i} http://localhost:777${i} {
    websocket
  }
FOO
   done )

  proxy / http://localhost:8080 {
    except /404.html
    except /ws-conn
$(seq 0 9 | sed  's;^;    except /ws-conn;g')
  }
}
EOF

# defualt port 80 443
export CADDYPATH=/etc/ssl/caddy
/usr/bin/caddy -log stdout -agree=true -conf=/etc/caddy/Caddyfile -root=/var/tmp
