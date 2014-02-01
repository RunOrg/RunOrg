# Installing RunOrg

The following instructions assume a Debian Unstable distribution. 
They will build the RunOrg server from source.

**[We are looking for help](https://github.com/RunOrg/RunOrg/issues/2)** 
for packaging RunOrg. If you're proficient with a deployment tool, lend 
us a hand ! 

## Installing Debian packages

We tried our best to have as little Debian dependencies as possible. 
It is very likely that your distribution of choice has packages 
equivalent to the following: 

    apt-get install git make postgresql m4 daemontools \
        libssl-dev libssl-dev libcurl4-gnutls-dev libpq-dev \ 
        opam
        
## Setting up a PostgreSQL database

RunOrg uses PostgreSQL as a back-end. Using any method, please create 
a new database (such as `runorgdb`) and a new user (such as `runorguser`) 
with a password (such as `I<3owls`). 

For now, [don't use a semicolon in the password](https://github.com/RunOrg/RunOrg/issues/4). 

This is no place for a PostgreSQL lesson, but here's a quick guide that 
might work for you: 

    -- Log in as a superuser -- 
    psql 
    CREATE USER runorguser WITH PASSWORD 'I<3owls';
    CREATE DATABASE runorgdb WITH OWNER runorguser;
    \q 
    
## Grabbing a copy of the RunOrg code
    
This is up to you. You may grab a compressed archive from the 
[releases](https://github.com/RunOrg/RunOrg/releases) section of this
repository, or you may clone the repository using its public HTTPS
clone url [https://github.com/RunOrg/RunOrg.git](https://github.com/RunOrg/RunOrg.git).

For instance: 

    git clone https://github.com/RunOrg/RunOrg.git
    
## Initializing Opam

Now that the code is available, you need to install any OCaml modules
required to build the server. The Debian packages are usually out of
date, so RunOrg uses Opam (the OCaml package manager) instead. 

You need to initialize Opam by running this command and following the
instructions it prints: 

    opam init
    
## Building the RunOrg server

The easiest step: 

    make depend runorg -C RunOrg
    
This will create a `runorg` executable in the project root directory.
Don't touch it yet: we need to configure it first.

## Creating a certificate

RunOrg uses HTTPS for all communications. This requires an OpenSSL-compatible 
certificate. Creating such a certificate for a production environment is a
critical subject that cannot be covered in the install manual for a specific
product. If you know of a good resource on the topic, 
**[please mention it](https://github.com/RunOrg/RunOrg/issues/3)**.

On a development machine, you can use a self-signed certificate. The guide
below creates a key with password `L33t`: 

    openssl genrsa -des3 -passout pass:L33t -out key.pem 2048
    openssl req -new -key key.pem -out cert.csr
    openssl x509 -req -days 365 -in cert.csr -signkey key.pem -out cert.pem
    rm cert.csr
    
This would create files `key.pem` and `cert.pem` used by RunOrg. 

## Creating the configuration file

RunOrg reads configuration from a file named `conf.ini` in its own directory,
otherwise it looks for `/etc/runorg/conf.ini`. There is a default 
configuration file available: 

    cp RunOrg/conf.example.ini RunOrg/conf.ini
    
You will need to edit it. Most fields have good default values, the ones you 
need to change are: 

    ; database credentials
    db.name = runorgdb 
    db.user = runorguser 
    db.password = I<3owls
    
    ; key file, certificate file and key file password
    httpd.certificate = cert.pem
    httpd.key = key.pem
    httpd.key.password = L33t
    
    ; list of superadmin e-mails
    admin.list = foo@bar.com, baz@qux.com 
    
    ; the domain of the admin UI (for Persona)
    admin.audience = https://domain.com 
    
    ; salt used to generate session tokens
    token.key = randomcharacters 
    
## Starting the server

Assuming the server is not already running: 

    make start -C RunOrg
    
You can stop the server at any time with:

    make stop -C RunOrg
    
If you retrieve a more recent version (for instance, with `git pull`),
you can rebuild the server and reboot it in one command with:

    make -C RunOrg
