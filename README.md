# Pentest Lab

**I'm not actively developing on this anymore, but will fix bugs and look at
issues and pull requests.** Help is appreciated :)

This local pentest lab leverages docker compose to spin up multiple victim
services and an attacker service running Kali Linux.  If you run this lab for
the first time it will take some time to download all the different docker
images.

## Screencast

<a href="https://asciinema.org/a/VebTHWt6nZvTYJpvqWZja2kVb" target="_blank">
    <img
            src="https://asciinema.org/a/VebTHWt6nZvTYJpvqWZja2kVb.svg"
            align=right
            width=400px/>
</a>

**Executed commands:**

- `./lab.sh --help`
- `./lab.sh --check-dependencies`
- `./lab.sh --up --all-services`
- `./lab.sh --info`
- `./lab.sh --overview all`
- `ssh root@kali -o "UserKnownHostsFile /dev/null"`
- `./lab.sh --down`

## Usage

The lab should work out of the box if all needed dependencies are installed.
At startup the lab will run a dependency check.

### Start the lab

```bash
git clone https://github.com/oliverwiegers/pentest_lab
cd pentest_lab
./lab.sh -u
```

By default the lab will start all victim services and one red team service.
Other services can be started and added. More information on this down on this
below.

For further usage information consider reading the help message shown by
`./lab.sh -h | --help`.

### Dependencies

- bash
- find
- sed
- yq (The Python version. Not yq-go.)
- docker
- docker-compose

The lab has a build in dependency check which runs at startup. This also can be
run manually `./lab.sh -C`.

### Heimdall

<img src="./screenshots/heimdall.png" alt="img" align="left" width="400px">

For ease of use a [Heimdall](https://github.com/linuxserver/Heimdall) interface
was added that is exposed to `localhost:7000`.
All services that are exposed to your local machine and can be accessed via
browser are listed there.
Changes that will be made to the interface are automatically saved in
`./etc/heimheimdall`. This directory is than turned into `./etc/heimdall.tar`
while stopping the lab. This tar archive will be extracted on starup. Both
`./etc/heimdall.tar` and `./etc/heimdall` are ignored by git by default.

Used wallpaper can be found [here](https://wallpapercave.com/w/wp6241750).

## Services

This lab knows the following four types of services.

- red_team
- blue_team
- victim
- monitoring

The default red team service - the Kali service - is a pretty basic Kali
instance. Nonetheless `kali-tools-web` metapackage is installed. For a web
application testing lab the basic web testing tools seem to be useful.
This can be changed by editing the Dockerfile from which the image is
build. This is located at `./dockerfiles/kali`.
The kali service installs these
[dotfiles](https://github.com/oliverwiegers/dotfiles) by default. This is also
changable by tweaking the Dockerfile.

### Victim services

- [juice-shop](https://github.com/bkimminich/juice-shop)
- [hackazon](https://github.com/rapid7/hackazon)
- [tiredful-api](https://github.com/payatu/Tiredful-API)
- [WebGoat](https://owasp.org/www-project-webgoat/)
- [bwapp](http://www.itsecgames.com/)
- [DVWA](https://dvwa.co.uk/)
- [XVWA](https://github.com/s4n7h0/xvwa)
- [ninjas](https://umbrella.cisco.com/blog/security-ninjas-an-open-source-application-security-training-program)

### Monitoring services

<img src="./screenshots/grafana.png" alt="img" align="right" width="400px">
<img src="./screenshots/grafana_frontpage.png" alt="img" align="right" width="400px">

Even though monitoring services are blue_team services as well these are split
up in a different category.

This stack provides log and performance observation functionality.

For further information on single instances see below.

Currently the monitoring setup is made of the following services:

- [Grafana](https://grafana.com/oss/grafana/) - Visualize logs and metrics.
- [Loki](https://grafana.com/oss/loki/) - Ship docker logs to grafana.
- [Prometheus](https://grafana.com/oss/prometheus/) - Ship metrics to grafana.
- [cAdvisor](https://github.com/google/cadvisor) - Gather container ressource
  usage and metrics and ship to prometheus.

#### Grafana

The Grafana instance provides two dashboards one for logs and one for metrics.

- [Logs dashboard](https://grafana.com/grafana/dashboards/12611)
- [Metrics dashboard](https://grafana.com/grafana/dashboards/14282)

These are pretty basic. One could add more by adding dashboards via the Grafana
interface. These dashboards will be lost when the grafana volume is deleted. To
permanently add dashboards consult the [Provisioning
Docs](https://grafana.com/docs/grafana/latest/administration/provisioning/) by
Grafana. Used directories for provisioning are located at `./etc/grafana/`.

To change settings via Grafana interface one must login as `admin`. The
credentials are the default ones: `admin:admin`. #hacktheplanet

#### Loki

For Loki beeing able to gather docker logs this lab installs the [Loki Docker
Driver](https://grafana.com/docs/loki/latest/clients/docker-driver/) as Docker
plugin.

#### Prometheus / cAdvisor

For Prometheus beeing able to access performance metrics of the containers
running in the cluster cAdvisor is used.

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
│   ├── cadvisor.yml
│   ├── grafana.yml
│   ├── loki.yml
│   └── prometheus.yml
├── red_team
└── victim
    ├── beginner
    │   ├── bwapp.yml
    │   ├── dvwa.yml
    │   ├── hackazon.yml
    │   ├── tiredful.yml
    │   ├── webgoat.yml
    │   └── xvwa.yml
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

#### IP ranges

The reason we used static IP addresses is that the Kali box needs to have an IP
address that doesn't change to simplify SSH login. More in information in the
Tips/Tricks section down below.

- Red team services start at 10.5.0.5
    - The Kali service has 10.5.0.5.
- Blue team services start at 10.5.0.50
- Victim services start at 10.5.0.100
- Monitoring services start at 10.5.0.200

#### Service Info

If you add services and there is additional information that is useful for
anyone running this lab you can add this information to `./etc/services_info`.
Content of this file will be printed as is line by line by running
`./lab.sh -i`.

## Tips/Tricks

### SSH

For an easy connect to the Kali service one could add the following to
`$HOME/.ssh/cofig`:

```ssh-config
Host kali
    User root
    Hostname 10.5.0.5
    UserKnownHostsFile /dev/null
    StrictHostKeyChecking accept-new
```

So instead of `ssh root@10.5.0.5 -o "UserKnownHostsFile /dev/null"` one could
run `ssh kali`.

For tmux users the following will attach to a tmux session automatically:

```ssh-config
Host kali
    User root
    Hostname 10.5.0.5
    UserKnownHostsFile /dev/null
    StrictHostKeyChecking accept-new
    RequestTTY yes
    RemoteCommand tmux -L tmux new-session -As hacktheplanet
```
