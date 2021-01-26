# Compile and install nginx source code
# author wangjinhuai

# Using the operating system Centos 6 and 7

#!/bin/bash
export PATH=$PATH:/bin:/usr/bin:/usr/local/bin:/usr/sbin

NGINX_ROOT="/data/www/wwwroot"

NINGX_PATH="/etc/nginx"
BIN_PATH="/usr/sbin"
LOG_PATH="/var/log/nginx"
NGINX_PORT=80
NGINX_USER=nginx
NGINX_GROUP=nginx
NGINX_VERSION="nginx-1.19.1"
NGINX_PREFIX="${NINGX_PATH}"
NGINX_PCRE_VERSION="pcre-8.40"
NGINX_ZLIB_VERSION="zlib-1.2.11"
NGINX_OPENSSL_VERSION="openssl-1.1.0l"
NGINX_COMPILE_COMMAND="./configure \
--prefix=${NINGX_PATH} \
--sbin-path=${BIN_PATH}/nginx \
--conf-path=${NINGX_PATH}/nginx.conf \
--error-log-path=${LOG_PATH}/error.log \
--pid-path=/var/run/nginx.pid \
--lock-path=/var/lock/nginx.lock  \
--http-log-path=${LOG_PATH}/access.log \
--http-client-body-temp-path=${NINGX_PATH}/client_temp \
--http-proxy-temp-path=${NINGX_PATH}/proxy_temp \
--http-fastcgi-temp-path=${NINGX_PATH}/fastcgi_temp \
--http-uwsgi-temp-path=${NINGX_PATH}/uwsgi_temp \
--http-scgi-temp-path=${NINGX_PATH}/scgi_temp \
--with-pcre=../$NGINX_PCRE_VERSION \
--with-openssl=../$NGINX_OPENSSL_VERSION \
--with-zlib=../$NGINX_ZLIB_VERSION \
--user=nginx \
--group=nginx \
--with-stream \
--with-http_ssl_module \
--with-http_v2_module \
--with-http_gzip_static_module  \
--with-file-aio --with-ipv6 \
--with-http_realip_module \
--with-http_gunzip_module \
--with-http_secure_link_module \
--with-http_stub_status_module
"

printf "clear all environments"
rm -rf zlib* pcre* nginx*  openssl*
rm -rf /etc/yum.repos.d/epel*

echo "install dependent package"
yum install -y nmap unzip wget lsof xz net-tools gcc make gcc-c++ epel-release ntp

echo "sync ntp"
ntpdate asia.pool.ntp.org
timedatectl set-timezone "Asia/Shanghai"

echo "stop firewalld"
systemctl stop firewalld
systemctl disable firewalld

#[ -d /var/nginx/client ] || mkdir -p /var/nginx/client
   
if [[ $(id nginx) = "0" ]]; then
    printf "nginx group and user is exist\n"
else
    groupadd -r nginx
    useradd -r -g nginx -s /bin/false -M nginx
fi

#install zlib package

if [ -f $NGINX_ZLIB_VERSION.tar.gz ]; then
    echo $NGINX_ZLIB_VERSION.tar.gz is exist.
else
    wget -c https://www.zlib.net/$NGINX_ZLIB_VERSION.tar.gz --no-check-certificate
fi
tar zxvf $NGINX_ZLIB_VERSION.tar.gz 
cd $NGINX_ZLIB_VERSION
./configure && make && make install
cd ../

#install pcre package
# the package is not real package instead of it.
if [ -f $NGINX_PCRE_VERSION.tar.gz ]; then
    echo $NGINX_PCRE_VERSION.tar.gz is exist.
else
    wget https://ftp.pcre.org/pub/pcre/${NGINX_PCRE_VERSION}.tar.gz --no-check-certificate
fi
tar zxvf $NGINX_PCRE_VERSION.tar.gz 
cd $NGINX_PCRE_VERSION
./configure && make && make install
cd ../

#install openssl and nginx package

if [ -f  $NGINX_OPENSSL_VERSION.tar.gz ]; then
    echo $NGINX_OPENSSL_VERSION.tar.gz is exist.
else
    wget https://www.openssl.org/source/${NGINX_OPENSSL_VERSION}.tar.gz --no-check-certificate
fi

if [ -f  $NGINX_VERSION.tar.gz ]; then
    echo $NGINX_VERSION.tar.gz is exist.
else
    wget -c http://nginx.org/download/$NGINX_VERSION.tar.gz
fi   
tar zxvf $NGINX_OPENSSL_VERSION.tar.gz
tar zxvf $NGINX_VERSION.tar.gz
cd $NGINX_VERSION
useradd nginx -s /sbin/nologin -M
$NGINX_COMPILE_COMMAND
make  && make install

cat  > /etc/init.d/nginx << 'EOF'
#!/bin/sh
# chkconfig: - 85 15

# description: nginx is a World Wide Web server. It is used to serve
. /etc/rc.d/init.d/functions

if [ -f /etc/sysconfig/nginx ]; then
    . /etc/sysconfig/nginx
fi

prog=nginx
nginx=\${NGINX-${NINGX_PATH}/nginx}
conffile=\${CONFFILE-${NINGX_PATH}/nginx.conf}
lockfile=\${LOCKFILE-/var/lock/nginx.lock}
pidfile=\${PIDFILE-var/run/nginx.pid}
SLEEPMSEC=100000
RETVAL=0

start() {
    echo -n \$"Starting \$prog: "

    daemon --pidfile=\${pidfile} \${nginx} -c \${conffile}
    RETVAL=\$?
    echo
    [ \$RETVAL = 0 ] && touch \${lockfile}
    return \$RETVAL
}

stop() {
    echo -n \$"Stopping \$prog: "
    killproc -p \${pidfile} \${prog}
    RETVAL=\$?
    echo
    [ \$RETVAL = 0 ] && rm -f \${lockfile} \${pidfile}
}

reload() {
    echo -n \$"Reloading \$prog: "
    killproc -p \${pidfile} \${prog} -HUP
    RETVAL=\$?
    echo
}

upgrade() {
    oldbinpidfile=\${pidfile}.oldbin

    configtest -q || return 6
    echo -n \$"Staring new master \$prog: "
    killproc -p \${pidfile} \${prog} -USR2
    RETVAL=\$?
    echo
    /bin/usleep \$SLEEPMSEC
    if [ -f \${oldbinpidfile} -a -f \${pidfile} ]; then
        echo -n \$"Graceful shutdown of old \$prog: "
        killproc -p \${oldbinpidfile} \${prog} -QUIT
        RETVAL=\$?
        echo
    else
        echo \$"Upgrade failed!"
        return 1
    fi
}

configtest() {
    if [ "\$#" -ne 0 ] ; then
        case "\$1" in
            -q)
                FLAG=\$1
                ;;
            *)
                ;;
        esac
        shift
    fi
    \${nginx} -t -c \${conffile} \$FLAG
    RETVAL=\$?
    return \$RETVAL
}

rh_status() {
    status -p \${pidfile} \${nginx}
}

# See how we were called.
case "\$1" in
    start)
        rh_status >/dev/null 2>&1 && exit 0
        start
        ;;
    stop)
        stop
        ;;
    status)
        rh_status
        RETVAL=\$?
        ;;
    restart)
        configtest -q || exit \$RETVAL
        stop
        start
        ;;
    upgrade)
        upgrade
        ;;
    condrestart|try-restart)
        if rh_status >/dev/null 2>&1; then
            stop
            start
        fi
        ;;
    force-reload|reload)
        reload
        ;;
    configtest)
        configtest
        ;;
    *)
        echo \$"Usage: \$prog {start|stop|restart|condrestart|try-restart|force-reload|upgrade|reload|status|help|configtest}"
        RETVAL=2
esac

exit \$RETVAL
EOF
chmod +x /etc/init.d/nginx
chkconfig --add nginx
chkconfig nginx on
service nginx start
ss -tunlp | grep nginx
if [ $? -eq 0 ];then
    echo "install nginx sucessful"
else
    echo "install nginx failed"
    exit 1
fi

