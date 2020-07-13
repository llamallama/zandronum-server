# Zandronum Server Docker Images

Credit goes to https://github.com/rcdailey/zandronum-server for providing an excellent start point for this project.

Host your Zandronum server using Docker! Automatically deploy it and configure it with Rancher!

* [Docker Hub](https://hub.docker.com/r/llamallama/zandronum-server)
* [Github Repository](https://github.com/llamallama/zandronum-server)

## Installation and Usage

This was is a fully functional Zandronum server container built from the official Zandronum repos.
It was designed with deploying it to Rancher in mind, but can also be deployed using Docker Compose.
Below is an example that will help get you started on setting up your own server. There isn't one
true way to configure things; there's a lot of flexibility. But it is easier to start by using this
example and then adjusting it as needed.

```yml
version: '3.7'

services:
  coop:
    build: ../
    image: zandronum-server
    restart: always
    network_mode: host
    ports:
    - 10666:10666/udp
    volumes:
    - ./data:/data:ro
    command: coop
    environment:
      - joinpassword=joinpasswordhere
      - rconpassword=rconpasswordhere
  invasion:
    build: ../
    image: zandronum-server
    restart: always
    network_mode: host
    ports:
    - 10667:10667/udp
    volumes:
    - ./data:/data:ro
    command: invasion
    environment:
      - joinpassword=joinpasswordhere
      - rconpassword=rconpasswordhere
```

Customization of your Zandronum instances will be done through a combination of command arguments
and configuration files. In the example above note `coop` and `invasion` after the `command:`
property.  Those correspond to folders in the [servers/configs](servers/configs) directory. The
directory structure looks like this:

```
servers/configs/
├── coop
│   ├── brutal
│   │   ├── maps.cfg
│   │   ├── params.template
│   │   └── server.cfg
│   └── current
├── global
│   └── global.cfg.template
└── invasion
    ├── armageddon_samsara
    │   ├── maps.cfg
    │   ├── params.template
    │   └── server.cfg
    └── current
```

Given this example, here is how you create your own setup.
1. Create a game mode folder inside of [servers/configs](servers/configs). Use something like `coop`,
   `invasion`, or `deathmatch`. For the rest of this example we'll use
   [servers/configs/coop](servers/configs/coop).
2. Create a configuration folder inside of the game mode folder. You can create as many as you like.
   This example is using [servers/configs/coop/brutal](servers/configs/coop/brutal).
3. Place your config files inside of that configuration folder.
4. Next to those, create a file called `params.template`. It should look something like this.
```
params=(
  -port 10666
  -iwad /data/DOOM2.WAD
  -file /data/brutalv21.pk3
  +exec /configs/global/global.cfg
  +exec /configs/coop/${CURRENT_SERVER}/server.cfg
  +exec /configs/coop/${CURRENT_SERVER}/maps.cfg
)
```
5. Edit the `current` file in the game mode folder. For example,
   [servers/configs/coop/current](servers/configs/coop/current).  This will only contain one line
   and one word, the name of the configuration folder to use. Using this, you can switch between
   multiple setups in the game mode folder.
6. Add your wads to the `servers/data` directory.
7. Run `docker-compose up` to test.
8. (Optional) push your changes to your own copy of this repo to trigger CI/CD through Rancher.


## Rancher

[.rancher-pipeline.yml](.rancher-pipeline.yml) exists to set up Rancher's CI/CD tool. That, coupled
with either of the deployment files in [rancher](rancher), provide an automated way of changing the
configuration of and redeploying your Doom servers.

## Networking

### Host Networking

Due to the inflexible nature of how Zandronum's networking code functions, I recommend using `host`
network mode (reflected in my example above). If you prefer more network isolation and would like to
use `bridge` network mode, please read the following section.

### Bridge Networking

If you use `bridge` networking, LAN broadcasting (via `sv_broadcast`) does not work properly. This
is because Zandronum advertises the bound IP address (which is on the docker bridge subnet), which
your LAN subnet will not have direct access to. Other than that, though, everything works. The
sub-sections below go into more detail.

#### Port Numbers

Typically with Docker containers, if you want to run multiple instances of a service and run them
each on different ports, you would simply map a different port on the host. However, the way
Zandronum works requires some special configuration. Zandronum reports its own listening port to the
master server.

Because of this, you *must* specify a different listening port for Zandronum by giving the `-port`
option. Note that this is only a requirement if you plan to run two or more instances of this
container.

If you change the port, make sure you map that to the host. Using the example above, I used port
`10667` and which you would map to the host by adding the following additional YAML to your
`docker-compose.yml` file:

```yml
    ports:
    - 10667:10667/udp
```

Be sure to update your `params.template` and Rancher deployment files as well.

#### IP Address

It's worth noting that in bridge network mode, the IP address that Zandronum is listening on is
*not* reported to the master server. Actually, the master server will list whatever IP address it
received packets from, which will be your public IP, not the Docker bridge IP. So, no additional
configuration is needed for connecting via master server.

Do remember, however, that the incorrect IP address is broadcast for LAN games, so if this is
important, please use `host` for your `network_mode:` setting.

## PWAD / IWAD Selection

Put all your WAD files (PWAD + IWAD) in a directory and map that as a volume into the container. You
can put it anywhere. In my case, I mounted my WAD directory to `/data` in the container.

In `params.template`, provide the path to the main IWAD by using the `-iwad` option. Specify the
`-file` argument one or more times to add more PWADs to your server (such as the Brutal Doom mod).
Depending on how you mapped your volumes, you may specify individual PWAD files:

    -file /data/mywad.pk3

## User & Group

Inside the container, `zandronum-server` runs as user `doomguy` and group `zandronum`. The
corresponding UID and GID is determined by Docker. If you want to have explicit control over either
the UID or GID used inside the container, you can specify the following environment variables. Note
that overriding this behavior is really only useful if you want to properly map file permissions in
your host volumes to the user running in the container.

* `ZANDRONUM_UID`<br>
  The User ID on the *host machine* that will be assigned to the `doomguy` user in the container.
* `ZANDRONUM_GID`<br>
  The Group ID on the *host machine* that will be assigned to the `zandronum` group in the
  container.

Note that it is an error to run this image using the `-u`/`--user` argument to `docker run` or the
`user:` property in `docker-compose.yml`. The container *itself* must start as a root user, but the
`zandronum-server` process is started using the local user & group.

### Examples

As an example, you can add the following attributes to the existing YAML example file (shown
earlier) which will assign the `doomguy` user to UID 1000 and GID 1050:

```yml
environment:
- ZANDRONUM_UID=1000
- ZANDRONUM_GID=1050
```

Or you can map these to environment variables you defined in your `~/.bashrc`, for example (based on
Ubuntu 20.04):

```bash
export UID
export GID="$(id -g)"
```

Which you would use in your `docker-compose.yml` like so:

```yml
environment:
- ZANDRONUM_UID=$UID
- ZANDRONUM_GID=$GID
```

## Configuration Files

For in-depth configuration, especially related to controlling how game play will work on your server,
you should provide configuration files. How you structure these files and how they are named are up
to you. I personally choose the `.cfg` extension. The docker build process copies the config files
in `servers/configs` to `/configs` in the container.

I'll provide the contents of the config files I used in the above example. Some of these you will
want, such as the master server list configuration. But mostly this is meant to give you some ideas
on how to set up your server.

### `/servers/configs/global/global.cfg`

This is the configuration I give to *all* of my servers, regardless of their purpose.

```
set sv_broadcast 0
set sv_updatemaster 1
set sv_enforcemasterbanlist true
set sv_password ${JOIN_PASSWORD}
set sv_rconpassword ${RCON_PASSWORD}
set sv_forcepassword true
set sv_markchatlines true
```

Notice the `sv_password` and `sv_rconpassword` values. They get replaced with the contents of the
environment variables `JOIN_PASSWORD` and `RCON_PASSWORD`. Those can either be set via Docker
Compose or in your Rancher deployment. I'm using Kubernetes secrets to fill those in for security.

### `/servers/configs/coop/brutal/server.cfg`

I keep my cooperative game play settings in its own config file. This one is isolated to the Brutal
Doom setup.

```
set sv_hostname "My Doom Server Title Here"

set sv_maxplayers 8
set sv_maxclients 8
set sv_unblockplayers 1
set sv_coop_loseinventory 0
set sv_coop_losekeys 0
set sv_coop_loseweapons 0
set sv_coop_loseammo 0
set sv_sharekeys 1
set sv_infiniteammo 1

set skill 3
set cooperative 1
set teamdamage 0
set compatflags 620756992
```

### `/servers/configs/coop/brutal/maps.cfg`

This last config is configures the maps.

```
sv_maprotation true
sv_randommaprotation 1
sv_samelevel false

addmap MAP01
addmap MAP02
addmap MAP03
addmap MAP04
addmap MAP05
```

## Building the Images

This can be done from `docker build` in the root of the directory or`docker-compose build` in the
`/servers` directory.
