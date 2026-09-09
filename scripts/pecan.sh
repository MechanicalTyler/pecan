# pecan — sourced shell function to build/run the pi sandbox container; see README.md.

# Rejects a value containing shell metacharacters; empty values pass through.
_pecan_validate() {
  case "$1" in
    "")
      return 0
      ;;
    *[!A-Za-z0-9/_.:-]*)
      echo "Error: value '$1' contains disallowed characters." >&2
      return 1
      ;;
  esac
  return 0
}

pecan() {
  local repo="${PECAN_REPO:-$HOME/projects/pecan}"
  local env_file="${PECAN_ENV_FILE:-$repo/pecan.env}"

  case "$1" in
    -b|--build)
      if [ ! -f "$env_file" ]; then
        echo "Error: pecan config '$env_file' not found. Copy pecan.env.example to pecan.env and edit it." >&2
        return 1
      fi
      . "$env_file"
      if ! _pecan_validate "$PECAN_BASE_IMAGE" || ! _pecan_validate "$PECAN_EXTRA_PACKAGES" \
        || ! _pecan_validate "$PECAN_USER" || ! _pecan_validate "$PECAN_HOME"; then
        return 1
      fi
      export PECAN_BASE_IMAGE PECAN_EXTRA_PACKAGES PECAN_USER PECAN_HOME
      (cd "$repo" && docker buildx bake -f docker-bake.hcl pecan)
      return
      ;;
    -l|--ls|--list)
      local running
      running="$(docker ps --format '{{.Names}}' | grep '^pecan-')"
      if [ -z "$running" ]; then
        echo "No pecan containers running."
        return
      fi
      echo "$running" | sed 's/^pecan-//'
      return
      ;;
    --rm)
      local target="$2"
      if [ -z "$target" ]; then
        echo "Error: --rm requires a container name." >&2
        return 1
      fi
      case "$target" in
        pecan-*) : ;;
        *) target="pecan-$target" ;;
      esac
      if ! docker ps --format '{{.Names}}' | grep -qw "$target"; then
        echo "Error: no running container named '$target'." >&2
        return 1
      fi
      local sock eid attached
      attached=0
      sock="$(docker context inspect -f '{{.Endpoints.docker.Host}}' 2>/dev/null | sed 's|^unix://||')"
      if [ -n "$sock" ]; then
        for eid in $(docker inspect -f '{{range .ExecIDs}}{{println .}}{{end}}' "$target" 2>/dev/null); do
          [ -z "$eid" ] && continue
          case "$(curl -s --unix-socket "$sock" "http://localhost/exec/$eid/json" 2>/dev/null)" in
            *'"Running":true'*)
              attached=1
              break
              ;;
          esac
        done
      else
        docker top "$target" -o pid,comm 2>/dev/null | grep -qw bash && attached=1
      fi
      if [ "$attached" = "1" ]; then
        echo "Error: '$target' has a live exec session. Detach before removing." >&2
        return 1
      fi
      docker kill "$target"
      return
      ;;
    "")
      echo "Error: container name required." >&2
      echo "Usage: pecan <name> | -b/--build | -l/--ls/--list | --rm <name>" >&2
      return 1
      ;;
    -*)
      echo "Error: unknown flag '$1'." >&2
      echo "Usage: pecan <name> | -b/--build | -l/--ls/--list | --rm <name>" >&2
      return 1
      ;;
  esac

  local container_name="pecan-$1"

  if docker ps --format '{{.Names}}' | grep -qw "$container_name"; then
    echo "Container '$container_name' already exists — attaching."
    docker exec -it "$container_name" bash
    return
  fi

  if [ ! -f "$env_file" ]; then
    echo "Error: pecan config '$env_file' not found. Copy pecan.env.example to pecan.env and edit it." >&2
    return 1
  fi
  . "$env_file"

  if ! _pecan_validate "$PECAN_HOSTNAME" || ! _pecan_validate "$PECAN_HOST_DIR" \
    || ! _pecan_validate "$PECAN_HOME" || ! _pecan_validate "$PECAN_VOLUME_NAME" \
    || ! _pecan_validate "$PECAN_MEMORY_LIMIT" || ! _pecan_validate "$PECAN_CPU_LIMIT"; then
    return 1
  fi

  if [ -z "$PECAN_HOST_DIR" ] || [ -z "$PECAN_HOME" ] || [ -z "$PECAN_VOLUME_NAME" ]; then
    echo "Error: pecan.env is missing a required value (PECAN_HOST_DIR, PECAN_HOME, PECAN_VOLUME_NAME)." >&2
    return 1
  fi

  # Sourced run hooks may append to this array via pecan_add_run_arg().
  local PECAN_EXTRA_RUN_ARGS=()
  pecan_add_run_arg() { PECAN_EXTRA_RUN_ARGS+=("$1" "$2"); }

  # find+process-substitution, not a bare glob: a bare `*.sh` glob with no
  # matches aborts under zsh's default nomatch option (this hook dir is
  # empty by default), and a `| while read` pipe would run the loop body in
  # a subshell, losing pecan_add_run_arg()'s writes to the array below.
  local hook
  while IFS= read -r hook; do
    . "$hook"
  done < <(find "$repo/hooks.d/run.d" -maxdepth 1 -type f -name '*.sh' 2>/dev/null | sort)

  echo "Container '$container_name' is new — creating."
  # --entrypoint overrides the image's `ENTRYPOINT ["pi"]` so the container
  # stays alive on a shell sleep instead of running `pi` with "sleep
  # 99999999" as its arguments.
  docker run --rm -d --name "$container_name" \
    --hostname "$PECAN_HOSTNAME" \
    --memory="${PECAN_MEMORY_LIMIT:-4g}" \
    --cpus="${PECAN_CPU_LIMIT:-2}" \
    -v "$PECAN_HOST_DIR:$PECAN_HOME" \
    -v "$PECAN_VOLUME_NAME:$PECAN_HOME/.pi/agent" \
    "${PECAN_EXTRA_RUN_ARGS[@]}" \
    --entrypoint sh \
    "${PECAN_IMAGE:-pecan:latest}" \
    -c 'sleep infinity'

  docker exec -it "$container_name" bash
  return
}
