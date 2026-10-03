# Solo Azeroth

Wrath of the Lich King **3.3.5a** (client build **12340**). Not Classic. Not Retail.

This repo is the source of truth. It contains the AzerothCore Playerbot server, `mod-playerbots`, and two more modules under `modules/` (see [Modules in the tree](#modules-in-the-tree)). Clone it and edit it here. It does not contain Blizzard client files. Two ways to run it:

- **Docker Compose** on your own machine, for you and a friend to test. AMP does not use this.
- **CubeCoders AMP**, as a normal process in the Create Instance list (same idea as ARK or 7 Days to Die). AMP downloads a Linux build from a GitHub Release and starts `authserver` and `worldserver` itself. There is no AMP Docker image and `DockerRequired` is false.

No release has been published yet. The compile is large, so `.github/workflows/release-linux.yml` is manual (`workflow_dispatch`) and was not run while this repo was created. AMP Update fails until that workflow has published `solo-azeroth-linux-x86_64.tar.gz`.

## Where the code came from

The files on `main` are what you build and edit. The URLs below are attribution for the import, not a checkout the build performs. `mod-playerbots` does not build against stock [azerothcore/azerothcore-wotlk](https://github.com/azerothcore/azerothcore-wotlk). Upstream's own install guide says to use the Playerbot fork. `liyunfan1223/mod-playerbots` now resolves to the org repo below.

| Piece | Upstream URL | Imported revision | Path in this repo |
| --- | --- | --- | --- |
| Core (branch `Playerbot`) | https://github.com/mod-playerbots/azerothcore-wotlk | `f19a18799a35f7c24bdcdc9ea399c601f166259b` | repository root (`src/`, `CMakeLists.txt`, `docker-compose.yml`) |
| Module (branch `master`) | https://github.com/mod-playerbots/mod-playerbots | `037c01418b5d01506917a3db9b44fd56ac5f965c` | `modules/mod-playerbots` |
| Individual progression | https://github.com/ZhengPeiRu21/mod-individual-progression | `723c510c685cca184d8b96b6c22452bd48fda23a` | `modules/mod-individual-progression` |
| Ollama chat | https://github.com/DustinHendrickson/mod-ollama-chat | `a9966f3e6b20efb98aab8b56ff9d997d8e1bcc06` | `modules/mod-ollama-chat` |

Those SHAs are recorded in `pins.env`. Docker, `scripts/bootstrap.sh`, and `.github/workflows/release-linux.yml` do not clone them. A newer upstream revision means importing that tree into this repo, not pointing the build at someone else's remote.

The imported core and `mod-playerbots` stay **GPL-2.0**. `mod-individual-progression` keeps the **MIT** `LICENSE` in its directory. `mod-ollama-chat` keeps the **AGPL-3.0** `LICENSE` in its directory. This repo does not relicense any of them. See `LICENSE` and each module's `LICENSE`.

## Modules in the tree

`modules/mod-individual-progression` and `modules/mod-ollama-chat` are real source trees, same idea as `modules/mod-playerbots`: committed here, not submodules, and not cloned by Docker, bootstrap, or CI. The directory names match the loader symbols in the imported core (`Addmod_individual_progressionScripts` and `Addmod_ollama_chatScripts`).

**Individual progression** is per character: Vanilla, then The Burning Crusade, then Wrath. Docker and the AMP world template set `IndividualProgression.Enable = 1` and `IndividualProgression.StartingProgression = 0`. Stage 0 is `PROGRESSION_START` in that module: Classic, level cap 60, Molten Core and Onyxia, not Wrath. Characters can still advance later. `IndividualProgression.ProgressionLimit` is left at its dist default of 0, which that conf file says means no limit. `IndividualProgression.SimpleConfigOverride` is left at its dist default of 1. That conf comment says this sets the two core options the module needs (`EnablePlayerSettings` and not enforcing DBC item attributes). This repo does not set those worldserver keys itself.

**Ollama chat** lets playerbots talk in character through an Ollama HTTP API. `OllamaChat.Enable = 1`. The URL key in `conf/mod_ollama_chat.conf.dist` is `OllamaChat.Url`, default `http://localhost:11434/api/generate`. Nothing useful happens until that URL is a running Ollama `/api/generate` endpoint. The module probes Ollama off the world thread, so worldserver does not need Ollama in order to boot. Docker does not override the URL. Inside the world container, localhost is the container, not your machine. Set `AC_OLLAMA_CHAT_URL` on `ac-worldserver` when you have an endpoint. The module README still says to use the liyunfan1223 core and playerbots forks. The tree is imported anyway. Compatibility with this repo's playerbots revision is not compile-tested.

**Not added:** dungeon-clear was left out on purpose. Real dungeon groups are future custom work, not another imported module.

**Playerbots and Naxxramas:** `AiPlayerbot.ApplyInstanceStrategies = 0`. That key exists in `modules/mod-playerbots/conf/playerbots.conf.dist` (dist default 1). It is the workaround named on [mod-playerbots issue 530](https://github.com/mod-playerbots/mod-playerbots/issues/530).

## What you must supply

- Docker (Compose v2) for the local test path, or AMP plus a Linux host for the panel path.
- Your own **Wrath 3.3.5a** client (build 12340). This repo does not download a client, MPQs, maps, vmaps, mmaps, dbc, or Cameras.
- A MySQL server AMP can reach, if you are not using the Docker database.

## Client data (still required)

Current docs still require files extracted from the client. The pinned `apps/extractor/extractor.sh` runs **inside the client directory** (the folder that contains `Wow.exe` and `Data/`). The [Linux server setup](https://www.azerothcore.org/wiki/linux-server-setup) says the same thing: copy the extractor binaries into the client directory, run them, then move the output next to the server. The Docker wiki's `ac-client-data-init` container instead **downloads** a data pack. This repo turns that command off.

Tools, in this order (names are the binaries, not the script):

| Step | Binary | Writes |
| --- | --- | --- |
| 1 | `map_extractor` | `dbc/`, `maps/`, `Cameras/` |
| 2 | `vmap4_extractor` then `vmap4_assembler Buildings vmaps` | `vmaps/` (and a `Buildings/` folder you can delete) |
| 3 | `mmaps_generator` | `mmaps/` |

`dbc`, `maps`, and `vmaps` are what the core docs say the server needs. `mmaps` is what lets creatures and bots walk. `Cameras` is produced by `map_extractor` and is recommended. Do not stop `vmap4_extractor` or `mmaps_generator` halfway. `mmaps_generator` can take hours. Do not commit any of these folders.

### Get the extractor binaries

They are built with the core. From this repo (after [Local test](#local-test-with-docker) and `.env`):

```bash
./scripts/dc.sh --profile tools build ac-tools
./scripts/dc.sh --profile tools run --rm --no-deps --entrypoint tar ac-tools \
  -C /azerothcore/env/dist/bin -cf - \
  map_extractor vmap4_extractor vmap4_assembler mmaps_generator \
  | tar -C /path/to/your/3.3.5a/client -xf -
```

The pinned `apps/docker/Dockerfile` copies those four binaries to `/azerothcore/env/dist/bin` in the `tools` image. The `ac-tools` service mounts a client `Data` folder for in-container extraction, but its working directory is `/azerothcore/env/client`, not the directory that holds the binaries. Copying them onto the client and running them there matches `extractor.sh`.

### Run them in the client directory

```bash
cd /path/to/your/3.3.5a/client
chmod +x map_extractor vmap4_extractor vmap4_assembler mmaps_generator
./map_extractor
mkdir -p Buildings vmaps mmaps
./vmap4_extractor
./vmap4_assembler Buildings vmaps
rm -rf Buildings
./mmaps_generator
```

`extractor.sh` in the core (`apps/extractor/extractor.sh`) is the menu around those same commands. Option 4 is "extract all".

### Where the folders go

Copy `dbc`, `maps`, `vmaps`, `mmaps`, and `Cameras` as **directories**, not packed into this git repo.

- Docker: `<this repo>/client-data/` so you have `client-data/dbc`, `client-data/maps`, and so on. That path is `DOCKER_VOL_DATA` in `.env.example`. Do not put extracts under `data/`; that directory is the core SQL tree.
- AMP: the **world** instance File Manager (or a copy on disk) at `serverfiles/data/` (dbc, maps, vmaps, mmaps, Cameras). `DataDir` in the world template defaults to `data`, and the process working directory is `serverfiles`. Auth does not need these files.

AMP's update only unpacks the GitHub Release (binaries, conf files, SQL). It does not run extractors and it does not contain client data.

## Local test with Docker

Requirements: Docker with Compose v2, git, and the extract above.

```bash
git clone https://github.com/Milzstream/azeroth-solo.git
cd azeroth-solo
cp .env.example .env
# set DOCKER_DB_ROOT_PASSWORD in .env before the first start
./scripts/bootstrap.sh
```

`bootstrap.sh` does not clone anything. It copies `sql/db_auth/2026_10_02_00_solo_azeroth_realm.sql` into `data/sql/custom/db_auth/`. The auth `updates_include` table marks `$/data/sql/custom/db_auth` as `CUSTOM`, so db-import applies that `UPDATE` and the realm name becomes **Solo Azeroth**.

Put the extracted folders in `client-data/` **before** the first `up`. `docker-compose.override.yml` replaces `ac-client-data-init` so it will not download data; it exits if `dbc`, `maps`, `vmaps`, or `mmaps` are missing.

```bash
./scripts/dc.sh build
./scripts/dc.sh up -d
```

`scripts/dc.sh` is:

```bash
docker compose \
  --project-directory . \
  -f docker-compose.yml \
  -f docker-compose.override.yml \
  --env-file .env \
  "$@"
```

The base compose file is `docker-compose.yml` in this repo. It starts `ac-database` (MySQL 8.4), `ac-db-import`, `ac-authserver`, and `ac-worldserver`. The world image is built from this tree with `modules/mod-playerbots`, `modules/mod-individual-progression`, and `modules/mod-ollama-chat` in the build context, which is how `apps/docker/Dockerfile` compiles modules (`COPY modules`). The override also bind-mounts `./modules` onto `/azerothcore/modules` because playerbots applies its SQL from that source path, and the worldserver runtime stage does not copy the module tree.

Logs: `./scripts/dc.sh logs -f ac-worldserver`. Stop: `./scripts/dc.sh down`.

## Windows (Docker Desktop)

On Windows, use PowerShell and Docker Desktop. The `.sh` files are for a Unix shell. This section does not use `cmd.exe`.

1. Install [Docker Desktop](https://www.docker.com/products/docker-desktop/) and leave it running. Compose v2 is included.
2. Clone this repo and open PowerShell in the clone (the folder that contains `docker-compose.yml`).
3. Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\windows.ps1
```

`scripts/windows.ps1` copies `sql/db_auth/*.sql` into `data/sql/custom/db_auth/`, then gets the Windows extractor tools and prints the folder they landed in. It does not clone anything. Docker Compose is the second step, and only after `client-data/` has the extracted directories.

That command does not install Visual Studio. It uses `gh` to download the latest successful Actions artifact named `windows-extractor-tools` (workflow `.github/workflows/windows-extractor-tools.yml`, `windows-latest`) into `env\dist\bin`. `gh auth login` is required. Actions artifacts are not an anonymous download. The artifact is `map_extractor.exe`, `vmap4_extractor.exe`, `vmap4_assembler.exe`, `mmaps_generator.exe`, `mmaps-config.yaml`, and any non-Windows DLLs those exes import. It is not a GitHub Release. AMP still looks at the latest release for `solo-azeroth-linux-x86_64.tar.gz`.

Copy every file from `env\dist\bin` into the Wrath 3.3.5a client directory (the folder with `Wow.exe` and `Data`). Run the tools there, in the order in [Client data](#client-data-still-required). `apps/extractor/extractor.bat` is only that menu. It does not compile them. The Docker `ac-tools` image in [Get the extractor binaries](#get-the-extractor-binaries) builds Linux binaries named `map_extractor`, not `map_extractor.exe`.

If `dbc`, `maps`, `vmaps`, or `mmaps` are missing, the script stops after the tools step and does not start Docker. Put those directories, plus `Cameras`, in `client-data/` (`DOCKER_VOL_DATA` in `.env.example`). Do not put extracts under `data/`. Copy `.env.example` to `.env`, set `DOCKER_DB_ROOT_PASSWORD` (replace `change-me`; an empty value makes the pinned compose file use `password`), and run the same command again. This repo does not download client data.

The same download without the script:

```powershell
gh run list --repo Milzstream/azeroth-solo --workflow windows-extractor-tools.yml --branch main --status success --limit 1
gh run download RUN_ID --repo Milzstream/azeroth-solo --name windows-extractor-tools --dir .\env\dist\bin
```

### Local MSVC build (heavy)

Skip this if the artifact download worked. It needs Visual Studio, Boost (`BOOST_ROOT`), a MySQL client library CMake can find, and OpenSSL (`OPENSSL_ROOT_DIR`). There is no separate cmake command line in the upstream Windows pages, so this repo does not invent one.

`apps/ci/ci-conf-tools.sh` sets `CAPPS_BUILD=none` and `CTOOLS_BUILD=maps-only`. `conf/dist/config.sh` reads those from the environment (`${CAPPS_BUILD:-all}`, `${CTOOLS_BUILD:-none}`). `maps-only` is the whitelist in `conf/dist/config.cmake` and `src/tools/CMakeLists.txt` for `map_extractor`, `vmap4_extractor`, `vmap4_assembler`, and `mmaps_generator`. `APPS_BUILD=none` does not build `authserver` or `worldserver`. `./acore.sh compiler build` is the entry point `.github/workflows/windows_build.yml` already uses (that workflow passes `CTOOLS_BUILD=all` and builds the whole server; this one does not). The Linux tools file also sets `CCOREPCH=OFF`. Do not do that on Windows. An MSVC build of `common` with core PCH off fails (`ASSERT`, `M_PI`, `std::string` come from the precompiled header). Leave `CCOREPCH` and `CSCRIPTPCH` at the compiler default, which is on.

From Git Bash, in this clone:

```bash
export CAPPS_BUILD=none
export CTOOLS_BUILD=maps-only
./acore.sh compiler build
```

Or:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\windows.ps1 -LocalBuild
```

On Git Bash, `OSTYPE` is `cygwin`. `apps/compiler/includes/functions.sh` runs `cmake --install` only for `msys*` and `linux*|darwin*`, so the exes stay in `var\build\obj\bin\Release\` (`CTYPE` defaults to `Release` in `conf/dist/config.sh`). For MSVC, `src/cmake/compiler/msvc/settings.cmake` sets `CMAKE_RUNTIME_OUTPUT_DIRECTORY` to `${CMAKE_BINARY_DIR}/bin`, which is why the configuration name is a subdirectory. That local build does not copy OpenSSL DLLs. [Windows core installation](https://www.azerothcore.org/wiki/windows-core-installation) says to copy `libcrypto-3-x64.dll` and `libssl-3-x64.dll` from the OpenSSL `bin` directory next to the executables.

The upstream [Windows core installation](https://www.azerothcore.org/wiki/windows-core-installation) page is the GUI path, not a cmake command: set `TOOLS_BUILD` to `all`, then Visual Studio `ALL_BUILD`, RelWithDebInfo, x64. [Windows server setup](https://www.azerothcore.org/wiki/windows-server-setup) copies the four exes from `C:\Build\bin\RelWithDebInfo\` when the build directory is `C:\Build`. That builds the whole server.

### Docker accounts

- MySQL user `root`. Password is `DOCKER_DB_ROOT_PASSWORD`. If that variable is empty, the pinned compose file uses `password`. Change it in `.env` before the first start. Port `DOCKER_DB_EXTERNAL_PORT` (3306).
- There is **no** pre-created game account. `account.sql` in the pinned core has an empty `account` table. The fork's `apps/docker/README.md` shows `account create admin password 3 -1`, but `cs_account.cpp` at this SHA parses that as name, password, and optional **email**. The GM level is a second command. From `docker attach ac-worldserver` (detach with Ctrl-P then Ctrl-Q, not Ctrl-C):

```text
account create <name> <password>
account set gmlevel <name> <level> -1
```

`-1` is every realm (`HandleAccountSetGmLevelCommand`). Pick a level the server accepts; this README does not assign a name to a number.

### Connect the client

Same machine as the server:

1. In the auth database, `realmlist.address` for id 1 is `127.0.0.1` and the port is `8085` (base `realmlist.sql`). Leave it if you play on this machine. Do not use the hostname `localhost`.
2. Edit `Data/enUS/realmlist.wtf` or `Data/enGB/realmlist.wtf` (whichever locale folder you have) and set the first line to `set realmlist 127.0.0.1`.
3. Auth port is **3724**, world port is **8085**.

The realm list entry is named **Solo Azeroth** after the custom SQL runs.

### Population and rates (Docker)

The override sets environment variables the pinned core maps onto conf keys:

| Variable | Conf key | Value here | Dist default |
| --- | --- | --- | --- |
| `AC_AI_PLAYERBOT_ENABLED` | `AiPlayerbot.Enabled` | 1 | 1 |
| `AC_AI_PLAYERBOT_RANDOM_BOT_AUTOLOGIN` | `AiPlayerbot.RandomBotAutologin` | 1 | 1 |
| `AC_AI_PLAYERBOT_MIN_RANDOM_BOTS` | `AiPlayerbot.MinRandomBots` | 50 | 500 |
| `AC_AI_PLAYERBOT_MAX_RANDOM_BOTS` | `AiPlayerbot.MaxRandomBots` | 150 | 500 |
| `AC_AI_PLAYERBOT_RANDOM_BOT_MAPS` | `AiPlayerbot.RandomBotMaps` | `0,1,530,571` | same |
| `AC_AI_PLAYERBOT_AUTO_DO_QUESTS` | `AiPlayerbot.AutoDoQuests` | 1 | 1 |
| `AC_MAP_UPDATE_THREADS` | `MapUpdate.Threads` | 4 | 1 |
| `AC_AI_PLAYERBOT_APPLY_INSTANCE_STRATEGIES` | `AiPlayerbot.ApplyInstanceStrategies` | 0 | 1 |
| `AC_INDIVIDUAL_PROGRESSION_ENABLE` | `IndividualProgression.Enable` | 1 | 1 |
| `AC_INDIVIDUAL_PROGRESSION_STARTING_PROGRESSION` | `IndividualProgression.StartingProgression` | 0 | 0 |
| `AC_OLLAMA_CHAT_ENABLE` | `OllamaChat.Enable` | 1 | 1 |

`OllamaChat.Url` is not set here. The dist value stays `http://localhost:11434/api/generate`. Add `AC_OLLAMA_CHAT_URL` on `ac-worldserver` only when you have a real endpoint. See [Modules in the tree](#modules-in-the-tree).

`RandomBotAutologin` is what logs random bots into the world, not only bots in your party. 50 / 150 is a lighter start than the module's 500 / 500. Maps `0,1,530,571` are Eastern Kingdoms, Kalimdor, Outland, and Northrend. XP, honor, and drop rates are not overridden, so they stay at the dist value **1**.

The worldserver image sets `AC_UPDATES_ENABLE_DATABASES=0` and runs core SQL in `ac-db-import`. Playerbots still uses `Playerbots.Updates.EnableDatabases` (dist default 1) inside worldserver, with `AC_PLAYERBOTS_DATABASE_INFO` already set on `ac-worldserver` in the fork's compose file. The module SQL path in this SHA is `modules/mod-playerbots/data/sql/`, not `modules/mod-playerbots/sql/` (that shorter path is an older wiki line and is wrong for this pin).

## AMP

AMP runs two instances because a Generic template has one executable. Create both from this repo after Fetch Latest:

| Template file | Process |
| --- | --- |
| `solo-azeroth-auth.kvp` | `bin/authserver` |
| `solo-azeroth-world.kvp` | `bin/worldserver` |

Both download the same release asset via `solo-azerothupdates.json` (`GithubRelease` on `Milzstream/azeroth-solo`).

1. On GitHub, Actions, run **release-linux** (`workflow_dispatch`). Wait until it publishes a release whose asset is exactly `solo-azeroth-linux-x86_64.tar.gz`. That has not happened yet.
2. In AMP: **ADS Instance Deployment, Configuration Repositories**. Add `Milzstream/azeroth-solo:main` next to `CubeCoders/AMPTemplates:main`. **Fetch Latest**.
3. Create an instance from **Solo Azeroth Auth** and one from **Solo Azeroth World**. Leave any container / Docker option **off**. These templates set `DockerRequired=False` and do not set `SpecificDockerImage` or `ContainerPolicy`.
4. Update each instance so AMP unpacks the release into `serverfiles/`.
5. On the world instance only, copy your extracted `dbc`, `maps`, `vmaps`, `mmaps`, and `Cameras` into `serverfiles/data/` with the File Manager or a disk copy. The template will not do this.
6. Install the MySQL client on the AMP host (`mysql` on `PATH`, or set **MySQL client** in the panel). The conf key `MySQLExecutable` is empty in the dist files and would otherwise keep the build machine's path.
7. The release sets `SourceDirectory` to `sql/core`. That tree is the core `data/sql` plus `modules/mod-playerbots/data`, `modules/mod-individual-progression/data`, and `modules/mod-ollama-chat/data`, so the built-in updater can load SQL without the GitHub runner path. `Updates.EnableDatabases` stays at the dist values (world **7**, auth **1**). `Updates.AutoSetup` stays **1**.
8. The upstream `data/sql/create/create_mysql.sql` (shipped at `sql/core/data/sql/create/create_mysql.sql`) creates MySQL user `acore` with password `acore`, and databases `acore_auth`, `acore_world`, and `acore_characters`. **Change that password** before you rely on it. It does not create `acore_playerbots`; the playerbots updater creates that database when `Playerbots.Updates.EnableDatabases` is 1.
9. Start **auth**, then **world**. The world console command to stop is `server exit` (pinned `cs_server.cpp`, `Console::Yes`). Auth is stopped by the process signal (`ExitMethod=OS_CLOSE`). Auth's ready line in the template is `Started auth database connection pool.` from `authserver/Main.cpp`. That line is before the network loop; there is no separate "listening" line in that file. World's ready line is `(worldserver-daemon) ready...`.
10. Create a game account on the world console the same way as Docker (`account create`, then `account set gmlevel`).

The panel edits conf keys through `solo-azeroth-worldconfig.json` and `solo-azeroth-authconfig.json`. Files written:

- Linux: `etc/worldserver.conf`, `etc/modules/playerbots.conf`, `etc/modules/individualProgression.conf`, `etc/modules/mod_ollama_chat.conf`, `etc/authserver.conf` (`-c` points at the main file; module conf is loaded from `etc/modules/` because the Linux build uses `-DCONF_DIR=etc`)
- Windows layout, same bytes: `configs/...` because `GetConfigPath()` on Windows is hard-coded to `configs/`

A Windows player would need `solo-azeroth-windows-x86_64.zip` with `bin/authserver.exe` and `bin/worldserver.exe`. The template lists that asset so the Create Instance list can show Windows as well as Linux (`Meta.OS=Windows, Linux`). **The workflow does not build it.** The fork's Windows CI (`windows_build.yml`) is a separate Boost and MySQL installer ending in `./acore.sh compiler build`, and it was not reproduced here. Until that zip exists, create the instances on Linux. A Windows update will fail looking for the zip.

### Settings the world panel exposes

All of these are keys in the pinned `worldserver.conf.dist` or `playerbots.conf.dist`. `IncludeInCommandLine` is false; they are written into the conf files.

- `WorldServerPort` (default 8085, TCP), `BindIP`, `DataDir` (default `data`), `RealmID` (default 1), `PlayerLimit` (default 1000)
- `LoginDatabaseInfo`, `WorldDatabaseInfo`, `CharacterDatabaseInfo`, `PlayerbotsDatabaseInfo` (dist strings use user `acore` / password `acore`; change them)
- `SourceDirectory` (default `sql/core`), `MySQLExecutable` (default `mysql`), `Updates.EnableDatabases` (default 7), `MapUpdate.Threads` (default 4 here; dist file says 1)
- `AiPlayerbot.Enabled` (1), `AiPlayerbot.RandomBotAutologin` (1), `AiPlayerbot.MinRandomBots` (50), `AiPlayerbot.MaxRandomBots` (150), `AiPlayerbot.RandomBotMaps` (`0,1,530,571`), `AiPlayerbot.AutoDoQuests` (1), `AiPlayerbot.ApplyInstanceStrategies` (0), `Playerbots.Updates.EnableDatabases` (1)
- `Rate.XP.Kill`, `Rate.XP.Quest`, `Rate.XP.Explore`, `Rate.Honor`, `Rate.Drop.Money` (all default 1)
- `IndividualProgression.Enable` (1) and `IndividualProgression.StartingProgression` (0), written to `etc/modules/individualProgression.conf` (and `configs/modules/` on the Windows layout)
- `OllamaChat.Enable` (1) and `OllamaChat.Url` (`http://localhost:11434/api/generate`), written to `etc/modules/mod_ollama_chat.conf`. Change the URL to a running Ollama `/api/generate` endpoint or chat does nothing useful. This template does not start Ollama.

Auth panel: `RealmServerPort` (3724, TCP), `BindIP`, `LoginDatabaseInfo`, `SourceDirectory`, `MySQLExecutable`, `Updates.EnableDatabases` (1).

`App.MaxUsers=1000` is AMP's own field. It is not wired to `PlayerLimit`. The game limit is the `PlayerLimit` setting.

### Not a panel setting

The realm **name** is column `realmlist.name` in `acore_auth`, not a conf key. The SQL file in this repo sets it to `Solo Azeroth`. Change it with SQL if you want a different name. Set `realmlist.address` to the IP the client should use when the client is not on the same machine.

Item drop rates other than `Rate.Drop.Money` exist (`Rate.Drop.Item.Poor` and the other quality keys) but are not in the panel. `App.MaxUsers` is not a conf key.

## Release asset

`solo-azeroth-linux-x86_64.tar.gz` (only after the workflow runs), laid out for AMP's `serverfiles/` directory:

- `bin/authserver`, `bin/worldserver`, `bin/dbimport`
- `etc/*.conf` and `etc/modules/playerbots.conf`, `etc/modules/individualProgression.conf`, and `etc/modules/mod_ollama_chat.conf`, plus a `configs/` copy
- `sql/core/data/sql` from the core, including the realm-name file under `custom/db_auth`
- `sql/core/modules/mod-playerbots/data`, `sql/core/modules/mod-individual-progression/data`, and `sql/core/modules/mod-ollama-chat/data`

Built on `ubuntu-22.04` with the same compiler packages as the fork's `core-build-playerbots.yml`, plus `-DCMAKE_INSTALL_PREFIX` and `-DCONF_DIR=etc`. The host that runs the binaries needs the MySQL client library, OpenSSL, and readline that this build links. The pinned Docker runtime image installs `libmysqlclient21` and `libreadline8` for that.

## Contributing

Clone the repo, branch from `main`, and open a normal pull request. Day to day, this repo commits straight to `main`. Do not force-push.

```bash
git clone https://github.com/Milzstream/azeroth-solo.git
cd azeroth-solo
git checkout -b my-change
# edit, then
git push -u origin my-change
```

If `git push` says it could not read a username, use:

```bash
git -c credential.helper='!gh auth git-credential' push
```

Do not commit `.env`, `client-data/`, logs, build output, or client extracts. The server source, including `src/` and `modules/mod-playerbots`, belongs in this repo. `pins.env` only records the import; editing it does not change what gets compiled.

## What this repo does not do

- It does not host or start a public realm.
- It does not clone AzerothCore, mod-playerbots, mod-individual-progression, or mod-ollama-chat when you build. Those trees are already here.
- It does not add dungeon-clear. Real dungeon groups are future custom work.
- It does not download or store client data.
- It does not ship an AMP container, and the templates do not name a Docker image.
- It does not run Ollama. `OllamaChat.Url` has to point at one before bot chat does anything useful.
