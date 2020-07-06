# Pentest Lab

This local pentest lab leverages docker compose to spin up multiple victim
services and an attacker service running Kali Linux.  If you run this lab for
the first time it will take some time to download all the different docker
images.

## Screencast

[![asciicast](https://asciinema.org/a/345707.png)](https://asciinema.org/a/345707)

## Usage

The lab should work out of the box if all needed dependencies are installed.
After starting the lab will run a dependency check to proof that all needed
software is installed.

### Start the lab

```bash
git clone https://github.com/oliverwiegers/pentest_lab
cd pentest_lab
./lab.sh -u
```

By default the lab will only start the victim services and one red team service.
Other services can be started and added. More information on this down on this
below.

For further usage information consider reading the help message shown by
`./lab.sh -h | --help`.

## Requirements

- bash
- find
- sed
- yq
- docker
- docker-compose

The lab has a build in dependency check which runs at startup. This also can be
run manually `./lab.sh -C`.

## Services

This lab knows the following four types of services.

- red_team
- blue_team
- victim
- monitoring

The default red team service - the Kali service - is a pretty basic Kali
instance. This can be changed by editing the Dockerfile from which the image is
build. This is located at `./dockerfiles/kali`.

Currently the blue team and monitoring services are not properly configured.
They only serve as examples to showcase the ability to add those.

### Victim services

- [juice-shop](https://github.com/bkimminich/juice-shop)
- [hackazon](https://github.com/rapid7/hackazon)
- [tiredful-api](https://github.com/payatu/Tiredful-API)
- [WebGoat](https://owasp.org/www-project-webgoat/)
- [bwapp](http://www.itsecgames.com/)
- [DVWA](http://www.dvwa.co.uk/)
- [ninjas](https://umbrella.cisco.com/blog/security-ninjas-an-open-source-application-security-training-program)

### Adding services

To add additional services a little knowledge of `docker-compose.yml` files is
needed. The `docker-compose.yml` in the root of this repository is auto
generated when the lab starts. This process uses the yaml files located unter
`./etc/services`.

```bash
➜  pentest_lab tree ./etc/services
./etc/services
├── blue_team
│   └── endlessh.yml
├── default.yml
├── monitoring
│   ├── grafana.yml
│   └── prometheus.yml
├── red_team
└── victim
    ├── beginner
    │   ├── bwapp.yml
    │   ├── dvwa.yml
    │   ├── hackazon.yml
    │   ├── tiredful.yml
    │   └── webgoat.yml
    ├── expert
    │   └── juice-shop.yml
    └── intermediate
        └── ninjas.yml
```

Which services will be started is controlled by invoking `./lab.sh` with the
corresponding options. To permanently disable a service remove the `.yml` file
extension.

An example of a victim service would be:

```yaml
bwapp:
  labels:
    class: 'victim'
    cluster: 'pentest_lab'
    level: 'beginner'
  image: raesene/bwapp
  ports:
    - '8080:80'
  networks:
    pentest_lab:
      ipv4_address: 10.5.0.100
  hostname: bwapp
  volumes:
    - bwapp-data:/var/lib/mysql
```

Note: If a service requires some kind of installation at first usage use
`docker inspect <image_name>` to find out where the docker image stores the data
and add a volume pointing to this directory. In the example above this is:

```yaml
  volumes:
    - bwapp-data:/var/lib/mysql
```

This ensures that you don't have to setup the service again every time you
restart the lab. But if you want to reset the lab and completely start over
again you can use `./lab.sh -p | --prune`. This will delete all resources owned by
the lab.

#### IP Ranges

The reason we used static IP addresses is that the Kali box needs to have a IP
address that doesn't change to simplify SSH login. More in information in the
Tips/Tricks section down below.

- Red team services start at 10.5.0.5
    - The Kali service has 10.5.0.5.
- Blue team services start at 10.5.0.50
- Victim services start at 10.5.0.100
- Monitoring services start at 10.5.0.200

## Tips/Tricks

For an easy connect to the Kali service one could add the following to
`$HOME/.ssh/cofig`:

```
Host kali
    User root
    Hostname 10.5.0.5
    IgnoreUnknown UseKeychain
    UseKeychain yes
    UserKnownHostsFile /dev/null
    StrictHostKeyChecking accept-new
```

So instead of `ssh root@10.5.0.5 -o "UserKnownHostsFile /dev/null"` one could
run `ssh kali`.

## TODO

- [ ] Refactor scripts.
- [ ] Write awesome readme.
- [ ] Record screencast and add to readme
- [x] Add more services.
- [x] Add option to specify additional service class to run.
    - [x] red_team Kali will be default, but other services can be added.
- [x] Make compose file generator script.
- [x] Let user spin up specific services or levels.
- [x] Generate SSH Keys if non is existing.
- [X] Add dependency check.
- [x] Add difficulty level.
- [x] Add clean function.
- [x] Add overview [all, monitoring, blue_team, red_team, victim].
- [x] Add control script - start,stop.
- [x] Add dynamic volume creation.
