# gitlab-ci-runner

FROM ubuntu:12.04
# Based on work of  Sytse Sijbrandij "sytse@gitlab.com"
MAINTAINER Kirill Pimenov "kirill@pimenov.cc"

# This script will start a runner in a docker container.
#
# First build the container and give a name to the resulting image:
# docker build -t gitlabhq/gitlab-ci-runner github.com/gitlabhq/gitlab-ci-runner
#
# Then set the environment variables and run the gitlab-ci-runner in the container:
# docker run -e CI_SERVER_URL=https://ci.example.com -e REGISTRATION_TOKEN=replaceme -e HOME=/root -e GITLAB_SERVER_FQDN=gitlab.example.com gitlabhq/gitlab-ci-runner
#
# After you start the runner you can send it to the background with ctrl-z
# The new runner should show up in the GitLab CI interface on /runners
#
# You can tart an interactive session to test new commands with:
# docker run -e CI_SERVER_URL=https://ci.example.com -e REGISTRATION_TOKEN=replaceme -e HOME=/root -i -t gitlabhq/gitlab-ci-runner:latest /bin/bash
#
# If you ever want to freshly rebuild the runner please use:
# docker build -no-cache -t gitlabhq/gitlab-ci-runner github.com/gitlabhq/gitlab-ci-runner

# Update your packages and install the ones that are needed to compile Ruby
RUN apt-get update -y
RUN apt-get install -y wget curl gcc libxml2-dev libxslt-dev libcurl4-openssl-dev libreadline6-dev libc6-dev libssl-dev make build-essential zlib1g-dev openssh-server git-core libyaml-dev postfix libpq-dev libicu-dev

# Download Ruby and compile it
RUN mkdir /tmp/ruby && cd /tmp/ruby && curl --progress http://ftp.ruby-lang.org/pub/ruby/1.9/ruby-1.9.3-p392.tar.gz | tar xz
RUN cd /tmp/ruby/ruby-1.9.3-p392 && ./configure --disable-install-rdoc && make && make install

# Fix upstart under a virtual host https://github.com/dotcloud/docker/issues/1024
RUN dpkg-divert --local --rename --add /sbin/initctl
RUN ln -s /bin/true /sbin/initctl

# Install packages commonly required to test Rails projects before the test run starts
# If they are not here you have to add them to the test script in the project settings
RUN apt-get install -y libqtwebkit-dev # test with capybara
RUN apt-get install -y redis-server
RUN apt-get install -y phantomjs

# Set the right locale for Postgres
RUN echo "LC_ALL=\"en_US.UTF-8\"" >> /etc/default/locale
RUN locale-gen en_US.UTF-8
RUN update-locale LANG=en_US.UTF-8

# Prepare a known host file for non-interactive ssh connections
RUN mkdir -p /root/.ssh
RUN touch /root/.ssh/known_hosts

# Install the runner
RUN git clone https://github.com/gitlabhq/gitlab-ci-runner.git /gitlab-ci-runner

# Install the gems for the runner
RUN cd /gitlab-ci-runner && gem install bundler && bundle install

# When the image is started add the remote server key, unstall the runner and run it
WORKDIR /gitlab-ci-runner
CMD ssh-keyscan -H $GITLAB_SERVER_FQDN >> /root/.ssh/known_hosts && mysqld & /root/redis-stable/src/redis-server & /etc/init.d/postgresql start & bundle exec ./bin/setup_and_run
