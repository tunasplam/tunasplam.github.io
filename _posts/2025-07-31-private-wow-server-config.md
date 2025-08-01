---
title: "Configuring and Starting Private WoW Servers"
date:  2025-07-31
categories: [programming]
tags: [games]
---

# Configuring and Starting Private WoW Servers

My early childhood consisted of Ultima Online and World of Warcraft. When I was older I wanted to rediscover that childhood so I found [CMaNGOS](https://cmangos.net/). I used this script to start and configure my private CMaNGOS servers.

Since I played the game solo but still wanted to experience end game content, I added a startup feature that optimized the settings in the server config file based on which gamemode I wanted to play on. There are separate settings for:

- solo play
- 5 - man instances
- 10 - man instances
- 20 - man instances
- 40 - man instances

The script itself was very fun to write and in this post we will look at the different components of the script in detail.

The full script code can be found in the corresponding [github repository](https://github.com/tunasplam/start-WoW).

# The Script

## Overview

There are three main components to the server: the mariadb database and the two scripts `realmd` and `mangosd`. Once all three services are up and running, you can start your WoW client `Wow.exe` and login to the server. There is also a config file which controls key attributes in your server such as drop rates, hp/damage scales, running speeds, chat settings, and much more. This program allows you to quickly start your server and game client with different "game-modes".

Here is the basic structure of the script:

```
Accept a 'game-mode' from the user
Set gamemode

check if database is running
    start if not

start server
wait a bit
start WoW client
```

### Validation

First we need to ensure that the env vars responsible for providing the required executable paths are set. We declare a list of required env vars and map a function over it which checks if each variable is set.

```python
REQUIRED_ENVVARS = [
    'SERVER_BIN_PATH',
    'WOW_EXE_PATH'
]

def check_envvar_set(v):
    try:
        environ[v]

    except KeyError:
        print(f"ERROR: Make sure to set env var {v}.")
        exit(1)

map(check_envvar_set, REQUIRED_ENVVARS)
```

### Parsing Commandline Args

I highly recommend `argparse` for handling user input for scripts meant to be run in terminal. It is painless to setup up, straightforward to use, and even sets up the `-h` help text for you.

Below we request a gamemode from the user. We should probably validate the user's input to restrict them to the correct options but this is a recreationally written personal use script so- corners get cut. 

```python
def parse_args():
    parser = argparse.ArgumentParser(description="Mode to set up server with.")
    parser.add_argument(
        "-m", "--mode",
        type=str,
        required=True,
        help="Specify the mode ('solo', '5-man', '10-man', '20-man', '40-man')"
    )
    return parser.parse_args().mode

mode = parse_args()
```

### Configuring the Server

Lets take a peek at the `mangosd.conf` file.


```shell
head mangosd.conf -n 15

#####################################
# MaNGOS Configuration file        
#
# To overwrite configuration fields with environment variables
# use the following pattern to generate environment variable names:
#
# For Rate.Health:
# export Mangosd_Rate_Health=1.2
#
# For DataDir:
# export Mangosd_DataDir=/tmp
#
#####################################
```

Well that makes things a bit easier, we can simply export environment variables with a certain structure to overwrite the variables in the config file. This means we can avoid interacting with the config file entirely.

Here is a simple config dict with sets of keys and values grouped by gamemode. Valid inputs for `--mode` should all have corresponding keys within this dict.

```python
PROFILES = {
    'solo': {
        'Mangosd_Rate_Creature_Normal': "1",
        'Mangosd_Rate_Creature_Elite_Elite': ".2",
        'Mangosd_Rate_Creature_Elite_RAREELITE': ".25",
        'Mangosd_Rate_Creature_Elite_WORLDBOSS': "1"
    },

    '5-man': {
        'Mangosd_Rate_Creature_Normal': ".25",
        'Mangosd_Rate_Creature_Elite_Elite': ".25",
        'Mangosd_Rate_Creature_Elite_WORLDBOSS': "1"
    },
    ...
}
```

Now the function below accepts our selected game mode and sets the specified variables associated with that game mode.

```python
def configure_mangosd(mode: str) -> dict:
    env = environ.copy()

    for (k, v) in PROFILES[mode].items():
        for stat in ("Damage", "SpellDamage", "HP"):
            env[f"{k}.{stat}"] = v

    return env
```

### Starting the MariaDB Service

Now we need to make sure that the MariaDB database which stores all of the player data and any values that the game would need to reference, such as data regarding specific items, creatures, or abilities. The idea is simple:

```python
if not db_service_active():
    start_db_service()
```

We check if the service is active by polling `systemctl`.

```python
def db_service_active() -> bool:
    # returns True if mariadb service is running
    try:
        result = subprocess.run(
            ["systemctl", "is-active", "mariadb"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            check=False
        )
        return result.stdout.strip() == "active"

    except Exception as e:
        print(f"Error checking service status: {e}")
        return False
```

If the service is not running, we start it and wait until it initializes. 

```python
def start_db_service(timeout=10):
    print("Starting MariaDB service...")
    result = subprocess.run(
        ["systemctl", "start", "mariadb"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False
    )
    time.sleep(2)

    if result.returncode != 0:
        print("ERROR: Failed to start mariadb service:")
        exit(1)

    wait_for_service_start()

def wait_for_service_start(timeout=10):
    start = time.time()
    while time.time() - start < timeout:
        if db_service_active():
            return True
    print("ERROR: Mariadb service timed out!")
    exit()
```

### Starting the mangosd and realmd Processes

After the database is started we then begin the two server scripts. This is made easy with calls to `subprocess.Popen`. We do not concern ourselves with logging because the scripts being called already have their own logs. We return the process ids in case they are needed elsewhere.

```python
def start_server(env: dict):

    realmd_proc = subprocess.Popen(
        ["./realmd"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        cwd=environ['SERVER_BIN_PATH'],
        env=env,
        preexec_fn=setsid
    )

    mangos_proc = subprocess.Popen(
        ["./mangosd"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        cwd=environ['SERVER_BIN_PATH'],
        env=env,
        preexec_fn=setsid
    )

    print("Waiting to give mangosd some time. You may need to wait longer if you have playerbots enabled.")
    time.sleep(120)
    return (realmd_proc, mangos_proc)
```

### Starting WoW Client

From here, all that is left to do is start the WoW client, a process which is again made easy with `subprocess.Popen`.

```python
def start_wow_client():
    return subprocess.Popen(
        ["wine", f"{environ['WOW_EXE_PATH']}"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE
    )
```

Please note that your server may not have finished loading before your WoW client loads. Although a 2 minute sleep is incorporated before starting the WoW client in order to give the server some time, you may need to wait longer, especially if you have the playerbot plugin installed. You can verify that the scripts are starting up by navigating to a separate shell and checking the output of:

```shell
ps aux | grep mangosd
ps aux | grep realmd
```

## Conclusion and Parting Thoughts

And there we have it, a nifty little script to save us time and it only requires a base python installation. This only took about an hour to throw together, and it saves quite a bit of time when starting up a solo private server, especially when soloing end game content such as 5-man, 10-man, and 40-man instances.

### Why python and not a bash script?
Bash is really fun to write and look at, but when it comes to quickly building a script that is easy to understand and maintain is much more important.

### How could this be made better?

The user inputted game mode setting is currently *not* being validated. The `-h` flag will spit out a help text specifying allowed options, but even those are hard-coded. Since the inputted values are the keys of the config dict, we could point the help text blurb at the list of keys and then use those keys to quickly validate the user's inputted game mode. If the input is invalid, we could `print_help()` and exit.

Config files could also be stored in separate `.env` files which are sourced based on your selected gamemode.
