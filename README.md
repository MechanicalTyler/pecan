# pecan

A reusable Docker sandbox and shell CLI for running the [pi coding agent](https://pi.dev)
(`@earendil-works/pi-coding-agent`) with limited access to the host machine.

pi does not sandbox its own tool execution — its bash tool runs with the invoking
user's full permissions, and pi's own docs recommend containerizing it. pecan is that
container, plus a `pecan` shell function to build and run it.

Every host-specific and org-specific value — hostname, host mount path, volume name,
extra OS packages, resource limits — lives in an external, gitignored config file. No
tracked file in this repo needs editing to adapt pecan to your machine or org.

## Prerequisites

- Docker Engine or Docker Desktop with the Buildx plugin (bundled by default in
  current releases — check with `docker buildx version`).
- `bash` or `zsh`.

## Setup

1. **Source the CLI.** Add this line to `~/.bashrc` or `~/.zshrc`, pointing at wherever
   you cloned this repo:

   ```sh
   source /path/to/pecan/scripts/pecan.sh
   ```

   Open a new shell (or `source` it directly) so the `pecan` function exists.

2. **Create your config.** Copy the tracked template to the gitignored real file and
   edit it:

   ```sh
   cp pecan.env.example pecan.env
   ```

   Set at minimum `PECAN_HOST_DIR` (the host directory to bind-mount as pi's
   workspace) and review the rest — see the comments in `pecan.env.example` for what
   each value controls. `pecan` looks for this file at `<repo>/pecan.env` by default;
   override the repo path with `PECAN_REPO` or the file path directly with
   `PECAN_ENV_FILE` if you keep it elsewhere.

3. **Build the image:**

   ```sh
   pecan --build
   ```

4. **Run it:**

   ```sh
   pecan mywork
   ```

   This creates (or attaches to) a container named `pecan-mywork`, mounts your
   configured host directory, and drops you into a shell where `pi` is on `PATH`.

## Config reference

`pecan.env` (copied from `pecan.env.example`) is sourced directly as shell by both
`scripts/pecan.sh` and, via exported environment variables, `docker-bake.hcl` — it is
the single source of truth for every externalized value:

| Variable | Used by | Meaning |
|---|---|---|
| `PECAN_HOSTNAME` | `pecan.sh` | Container hostname (`docker run --hostname`). |
| `PECAN_HOST_DIR` | `pecan.sh` | Host directory bind-mounted at `PECAN_HOME` inside the container — pi's workspace. |
| `PECAN_VOLUME_NAME` | `pecan.sh` | Docker named volume persisting pi's agent state, mounted at `PECAN_HOME/.pi/agent`. |
| `PECAN_BASE_IMAGE` | `docker-bake.hcl` | Base image tag for the build. |
| `PECAN_EXTRA_PACKAGES` | `docker-bake.hcl` | Space-separated extra `apt-get` packages. Quote multi-word values (e.g. `"jq curl"`) — this file is sourced as shell, so an unquoted space starts a new command. |
| `PECAN_USER`, `PECAN_HOME` | both | Non-root username and home directory baked into the image; `PECAN_HOME` also becomes the image's `WORKDIR` and the in-container mount target for `PECAN_HOST_DIR`. |
| `PECAN_MEMORY_LIMIT`, `PECAN_CPU_LIMIT` | `pecan.sh` | `docker run --memory` / `--cpus` limits. |

Every path-like or hostname value above is validated against a shell-metacharacter
allowlist before `pecan.sh` uses it in a docker command.

## CLI reference

| Command | Effect |
|---|---|
| `pecan <name>` | Create (or attach to) container `pecan-<name>`. |
| `pecan -b`, `--build` | Build the image from `docker-bake.hcl` + `pecan.env`. No container. |
| `pecan -l`, `--ls`, `--list` | List running `pecan-*` containers. |
| `pecan --rm <name>` | Kill and remove a container. Refuses if a live exec session is attached. |

## Writing a custom hook

pecan ships two hook directories, each with a tracked, inert example ending in
`.stub`:

- `hooks.d/build.d/00-example.sh.stub` — runs as root during `docker build`, after pi
  is installed and before the image switches to its non-root user. Use it for extra
  packages beyond `PECAN_EXTRA_PACKAGES`, baked credentials, plugin installs, git
  identity, or anything else that needs to exist inside the image.
- `hooks.d/run.d/00-example.sh.stub` — sourced on the host by `scripts/pecan.sh`
  before `docker run`. Call `pecan_add_run_arg "<flag>" "<value>"` to append extra
  `docker run` arguments (e.g. another bind mount).

To add a real hook, copy the relevant `.stub` file, drop the `.stub` suffix, make it
executable, and edit it. Both directories are gitignored except for the tracked
`.stub` examples, so real hooks never get committed. Hooks run in sorted filename
order — prefix with a number (`00-`, `10-`, ...) to control ordering.

## Extending pecan for your org

Today, the path above — real, executable, gitignored files under `hooks.d/build.d/`
and `hooks.d/run.d/` — is the only supported extension mechanism, and it is
local-only: those hooks live on your machine and are never committed to this repo.

The intended future path is a separate, git-tracked overlay repo per org (e.g.
`{yourorg}-pecan`) holding that org's real hooks, checked out independently and
layered on top of a pecan checkout. That keeps pecan itself permanently generic while
giving org-specific config a real, reviewable home instead of files that live only on
one person's disk. The wiring mechanism for that overlay repo is not yet designed —
for now, use the local `hooks.d/` path above.

## Tests

Run the lightweight shell-script tests from the repo root:

```sh
./test_pecan_env_validation.sh
./test_bake_config.sh
./test_build_hooks_discovery.sh
```

These exercise the real config-validation logic and the real `docker-bake.hcl` /
`scripts/run-hooks.sh` artifacts without requiring a full image build.
