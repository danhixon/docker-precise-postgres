#!/usr/bin/env bash

echo ""
echo "This script configures and starts a standby Postgresql"
echo "server inside of a Docker container."
echo "------------------------------------------------------"


# Default parameters
#
USER=$POSTGRESQL_USER
PASSWORD=$POSTGRESQL_PASSWORD
MASTER_ADDRESS=$MASTER_PORT_5432_TCP_ADDR
MASTER_PORT=$MASTER_PORT_5432_TCP_PORT
DATADIR=${POSTGRESQL_DATADIR:=/var/lib/postgresql/9.3/main}
BINDIR=${POSTGRESQL_BINDIR:=/usr/lib/postgresql/9.3/bin}
CONFIG_FILE=${POSTGRESQL_CONFIG_FILE:=/etc/postgresql/9.3/main/postgresql.conf}
HBA_FILE=${POSTGRESQL_HBA_FILE:=/etc/postgresql/9.3/main/pg_hba.conf}
IDENT_FILE=${POSTGRESQL_IDENT_FILE:=/etc/postgresql/9.3/main/pg_ident.conf}
MAX_CONNECTIONS=${POSTGRES_MAX_CONNECTIONS:=60}

# Custom die function.
#
die() { echo >&2 -e "\nRUN ERROR: $@\n"; exit 1; }


# Parse the command line flags.
#
while getopts ":u:p:d:c:h:s:" opt; do
  case $opt in
    u)
      USER=${OPTARG}
      ;;

    p)
      PASSWORD=${OPTARG}
      ;;

    d)
      DATADIR=${OPTARG}
      ;;

    c)
      CONFIG_FILE=${OPTARG}
      ;;

    h)
      HBA_FILE=${OPTARG}
      ;;

    i)
      IDENT_FILE=${OPTARG}
      ;;

    \?)
      die "Invalid option: -$OPTARG"
      ;;
  esac
done


# Create a shortcut postgres command with all
# the configuration options specified.
#
PGCMD=$BINDIR/postgres
PGARGS="-c config_file=$CONFIG_FILE -c data_directory=$DATADIR -c hba_file=$HBA_FILE -c ident_file=$IDENT_FILE"


# Both $USER and $PASSWORD must be specified if
# one of them is specified.
#
if [[ -z $USER ]]; then
	if [[ ! -z $PASSWORD ]]; then
		die "If you give a PASSWORD, you must supply a USER!"
	fi
else
	if [[ -z $PASSWORD ]]; then
		die "If you give a USER, you must supply a PASSWORD!"
	fi
fi


# If DATADIR does not exist, create it
#
if [ ! -d $DATADIR ]; then
  echo "Creating Postgres data at $DATADIR"
  mkdir -p $DATADIR
fi


# If DATADIR has no content, initialize it
#
if [ ! "$(ls -A $DATADIR)" ]; then
  echo "Initializing Postgres Database at $DATADIR"
  chown -R postgres $DATADIR
  su postgres sh -c "$BINDIR/initdb -E 'UTF-8' $DATADIR"
fi

# Create a user
#
if [[ ! -z $USER ]]; then
	echo "Setting up Postgresql user '$USER' with password '$PASSWORD'"
	echo "$PGCMD --single $PGARGS"
	su postgres sh -c "$PGCMD --single $PGARGS" <<< "CREATE USER $USER WITH SUPERUSER PASSWORD '$PASSWORD';"
fi
 
echo "Cleaning up data directory"
su postgres sh -c "rm -rf $DATADIR"

echo "Starting base backup as replicator"
export PGPASSWORD=$REPLICATOR_PASSWORD
su postgres sh -c "pg_basebackup -h $MASTER_ADDRESS -D $DATADIR -U replicator"
export PGPASSWORD=""

echo "Writing recovery.conf file"
su postgres sh -c "cat > $DATADIR/recovery.conf <<- _EOF1_
  standby_mode = 'on'
  primary_conninfo = 'host=$MASTER_ADDRESS port=$MASTER_PORT user=replicator password=$REPLICATOR_PASSWORD sslmode=require'
  trigger_file = '/tmp/postgresql.trigger'
_EOF1_
"

# Start the Postgresql process
#
echo "Starting Postgresql with the following options:"
echo -e "\t data_directory=$DATADIR"
echo -e "\t config_file=$CONFIG_FILE"
echo -e "\t hba_file=$HBA_FILE"
echo -e "\t ident_file=$IDENT_FILE"
echo -e "\t listen_addresses='*'"
su postgres sh -c "$PGCMD $PGARGS -c listen_addresses='*' -N $MAX_CONNECTIONS"
