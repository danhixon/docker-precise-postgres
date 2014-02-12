# -*- sh -*-

# Based on
# https://github.com/srid/discourse-docker/blob/master/postgresql/Dockerfile
FROM       	ubuntu:12.04
MAINTAINER  danhixon

# Prevent apt from starting postgres right after the installation
#
RUN echo "#!/bin/sh\nexit 101" > /usr/sbin/policy-rc.d; chmod +x /usr/sbin/policy-rc.d

# Set up the environment
#
ENV DEBIAN_FRONTEND noninteractive

# Fix encoding-related bug
# https://bugs.launchpad.net/ubuntu/+source/lxc/+bug/813398
#
RUN apt-get update
RUN apt-get -qy --fix-missing --force-yes install language-pack-en 
RUN update-locale LANG=en_US.UTF-8 LANGUAGE=en_US.UTF-8 LC_ALL=en_US.UTF-8

RUN dpkg-reconfigure locales
RUN apt-get update

# Get Ready:
RUN apt-get -y install wget 
RUN apt-get -y install python-software-properties

# Get Key:
RUN wget --quiet https://www.postgresql.org/media/keys/ACCC4CF8.asc
RUN apt-key add ACCC4CF8.asc

# Add Source & Update:
RUN sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt/ precise-pgdg main" >> /etc/apt/sources.list.d/postgresql.list'
RUN apt-get update

# Install postgresql 
RUN apt-get install -y -q postgresql-9.3 postgresql-contrib-9.3

RUN cp /etc/ssl/private/ssl-cert-snakeoil.key /etc/postgresql/9.3/main/server.key
RUN chown root:ssl-cert /etc/postgresql/9.3/main/server.key

RUN cp /etc/ssl/private/ssl-cert-snakeoil.key /etc/postgresql/9.3/main/server.key
RUN chown root:ssl-cert /etc/postgresql/9.3/main/server.key

# Allow autostart again
#
RUN rm /usr/sbin/policy-rc.d


# Move our files into the Docker image and make the
# entrypoint executable.
#
ADD start_postgres.sh /
RUN chmod a+x ./start_postgres.sh
ADD postgresql.conf /etc/postgresql/9.3/main/
ADD pg_hba.conf /etc/postgresql/9.3/main/


# Expose port 5432, the default Postgresql port, which will
# allow other container to connect to this container's Postgresql
#
EXPOSE 5432

# The entrypoint is our shell script.  You can pass in arguments
# to this shell script when you start the docker container, e.g.
#
#	$ docker run -d "danhixon/precise-postgres-9.3" -u docker -p docker
#
# where the -u and -p arguments are passed to the shell script.
#
ENTRYPOINT ["/start_postgres.sh"]
# default arguments
#CMD ["-u docker -p docker"]
