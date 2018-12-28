# Abiquo 2 Factor Authentication example

This project is intended to show a basic 2 factor authentication integration sample for Abiquo. Even if is a working sample, this is not production ready as some inputs would required to be sanitized and the 2 factor authentication workflow may require to be improved.

Requirements:

 * Ruby 2.2.0 or higher
 * Mysql and libs
 * Redis
 * Smtp relay
 * Cron daemon

## Installation:

This example has been developed, tested and documented under CentOS 6.5 version with software specified below but it may work in Ubuntu, MacOS or other OS as long as requirements are satisfied.

### Install Ruby:
```bash
# Install RVM GPG repository key
gpg2 --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3

# Install latest stable ruby version with RVM
\curl -sSL https://get.rvm.io | bash -s stable --ruby

# Load RVM environment
source /usr/local/rvm/scripts/rvm

```

### Install MySQL and libraries:
```bash
# Install MySQL client, server and libraries
yum install mysql mysql-server mysql-libs mysql-devel

# Start MySQL service:
service mysqld start

# You can set MySQL to start when boot
chkconfig mysqld on
```
### Install SMTP relay:
```bash
# Install Postfix server:
yum install postfix

# Start Postfix service:
service postfix start

# You can set Postfix to start when boot
chkconfig postfix on
```
### Install Cron daemon:
```bash
# Install Cron daemon:
yum install cronie

# Start Cron service:
service crond start

# You can set Postfix to start when boot
chkconfig crond on
```

### Install Redis:
```bash
# Add EPEL repositoy:
rpm -Uvh http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm

# Install Redis server:
yum install redis

# Start Redis service:
service redis start

# You can set Redis to start when boot
chkconfig redis on
```

### Download Abiquo2factor project and bundle:
```bash
# Get latest master Abiquo2factor version:
wget https://github.com/danfaizer/abiquo2factor/archive/master.zip

# Unzip project:
unzip abiquo2factor-master.zip

# Install required ruby gems:
cd abiquo2factor-master && bundle install
```

At this point, if all steps went well, the project is installed and almost ready to run.

## Configuration:
Before run Abiquo2factor, you must configure <code>config.yml</code> file with suitable values for your environment and create token database in MySQL server.

### Config.yml properties:
```yaml
mysql:
  user: root
  pass:
  db: token
  host: localhost
abiquo:
  api_url: https://10.60.13.29/api
  api_user: admin
  api_pass: xabiquo
  exclude_users: [1,2,3,4,5]
  session_timeout: 1800
  token_timeout: 300
smtp:
  smtp_user:
  smtp_pass:
  smtp_server: localhost
  smtp_port: 25
  mail_from: abiquo2f@mydomain.com
```
### Enable user session expiration in Cron
Abiquo2factor requires that Abiquo users are disabled when the token is being generated. To  force user use the 2 factor authentication we should enable a cron task that disables the user when session expires.

```bash
# To see the session expiration cron job execute:
whenever

# To enable the session expiration cron job execute:
whenever -w
```

By default, session expiration con job runs every 10 minutes, but you can easily change run schedule by editing cron <code>crontab -e</code> or modifying <code>tasks/schedule.rb</code> file.

### Create MySQL token database:
```bash
mysql -u root -Nse "create database token"
```

Abiquo2Factor is ready to run.

<code>DISCLAIMER:</code> Ensure to allow access in iptables to port 9292 (Default Sinatra rake port).

## Run:
Abiquo2factor uses [Resque](https://github.com/resque/resque) background job manager to talk with Abiquo API and deliever tokens to end user through email.

### Start Resque workers:
```bash
# Start at least 2 workers:
TERM_CHILD=1 QUEUE=* COUNT=2 rake resque:workers &
```

### Start Abiquo2Factor server:
```bash
bundle exec rackup -o 0.0.0.0 &
```

If everything is in place, you can now access http://IP:9292 , where IP is the IP address where Abiquo2Factor has been installed and access Abiquo via 2 factor authentication.
