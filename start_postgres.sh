#!/usr/bin/env bash

echo ""
echo "This script configures and starts Postgresql"
echo "inside of a Docker container."
echo "--------------------------------------------"


# Default parameters
#
USER=$POSTGRESQL_USER
PASSWORD=$POSTGRESQL_PASSWORD
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
  su postgres sh -c "$BINDIR/initdb $DATADIR"
fi


# Create a user
#
if [[ ! -z $USER ]]; then
	echo "Setting up Postgresql user '$USER' with password '$PASSWORD'"
	echo "$PGCMD --single $PGARGS"
	su postgres sh -c "$PGCMD --single $PGARGS" <<< "CREATE USER $USER WITH SUPERUSER PASSWORD '$PASSWORD';"
fi


# Start the Postgresql process
#
echo "Starting Postgresql with the following options:"
echo -e "\t data_directory=$DATADIR"
echo -e "\t config_file=$CONFIG_FILE"
echo -e "\t hba_file=$HBA_FILE"
echo -e "\t ident_file=$IDENT_FILE"
echo -e "\t listen_addresses='*'"
su postgres sh -c "$PGCMD $PGARGS -c listen_addresses='*' -N $MAX_CONNECTIONS"
