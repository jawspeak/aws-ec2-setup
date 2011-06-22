#!/usr/bin/env bash
SCRIPT_NAME=$0

usage() {
    cat <<EOF
Usage: $SCRIPT_NAME OPTIONS

Required:
 -D DATABASE_NAME        the database name
 -U DATABASE_USER        the database user. Defaults to DATABASE_NAME
Optional:
 -P DATABASE_PASSWORD    the database password. Defaults to autogenerate
 -L Sql Data file to load
EOF
}

die() {
    message=$1
    error_code=$2

    echo "$SCRIPT_NAME: $message" 1>&2
    usage
    exit $error_code
}

while getopts "hD:U:P:L:" opt; do
    case "$opt" in
        h)
            usage
            exit 0
            ;;
        D)
            export DATABASE_NAME="$OPTARG"
            ;;
        U)
            export DATABASE_USER="$OPTARG"
            ;;
        P)
            export DATABASE_PASSWORD="$OPTARG"
            ;;
	L)
	    export SQL_FILE="$OPTARG"
	    ;;
        [?])
            die "unknown option $opt" 10
            ;;
    esac
done

if [ -z "$DATABASE_NAME" ]; then
    die "DATABASE_NAME is required" 2
fi

if [ -z "$DATABASE_USER" ]; then
    die "DATABASE_USER is required" 2
fi

if [ -z "$DATABASE_PASSWORD" ]; then
    DATABASE_PASSWORD=`head -c 100 /dev/urandom | md5sum | awk '{print substr($1,1,15)}'`
fi

create_mysql_database() {
    cat <<EOF | mysql --user=root
CREATE DATABASE IF NOT EXISTS $DATABASE_NAME;
GRANT ALL PRIVILEGES  on $DATABASE_NAME.* to '$DATABASE_USER'@'%' identified by '$DATABASE_PASSWORD';
EOF
    touch ~/.my.cnf
    chmod 600 ~/.my.cnf
}

open_external_port() {
    cat <<EOF | sudo tee /etc/mysql/conf.d/listen_externally.cnf
[mysqld]
    bind-address = 0.0.0.0
EOF
    sudo /etc/init.d/mysql restart
}

print_mysql_config() {
    PUBLIC_DNS=`curl http://169.254.169.254/latest/meta-data/public-hostname 2>/dev/null`
    cat <<EOF
Database: $DATABASE_NAME
Username: $DATABASE_USER
Password: $DATABASE_PASSWORD
Public DNS: $PUBLIC_DNS
EOF
}

load_sql_data() {
    if [ -Z $SQL_FILE ]; then
	echo "skipping data load, no sql passed in";
    else
        #this does not prevent double-loading of data, not indepotent
	mysql --user=root -D $DATABASE_NAME < $SQL_FILE
    fi
}

create_mysql_database && open_external_port && print_mysql_config && load_sql_data