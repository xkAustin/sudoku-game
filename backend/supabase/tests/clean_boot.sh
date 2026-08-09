#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
data_migrations="$repository_root/backend/supabase/migrations"
edge_migrations="$repository_root/backend/supabase/edge_migrations"
postgres_image="${POSTGRES_IMAGE:-postgres:17.6-alpine@sha256:ef257d85f76e48da1c64832459b59fcaba1a4dac97bf5d7450c77753542eee94}"
container_name="sudoku-migration-clean-boot-$$"
postgres_password="clean-boot-disposable-only"

check_unique_versions() {
  local directory="$1"
  local label="$2"
  local versions=("__empty__")
  local file name version seen
  shopt -s nullglob
  for file in "$directory"/*.sql; do
    name="$(basename "$file")"
    if [[ ! "$name" =~ ^([0-9]{3})_.+\.sql$ ]]; then
      echo "$label migration has an invalid filename: $name" >&2
      exit 1
    fi
    version="${BASH_REMATCH[1]}"
    for seen in "${versions[@]}"; do
      if [[ "$seen" == "$version" ]]; then
        echo "$label migrations reuse version $version" >&2
        exit 1
      fi
    done
    versions+=("$version")
  done
  shopt -u nullglob
  if [[ "${#versions[@]}" -eq 1 ]]; then
    echo "$label migration directory is empty" >&2
    exit 1
  fi
}

cleanup() {
  local status=$?
  trap - EXIT
  docker rm --force "$container_name" >/dev/null 2>&1 || true
  exit "$status"
}
trap cleanup EXIT

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is required for the disposable PostgreSQL clean-boot test" >&2
  exit 127
fi

check_unique_versions "$data_migrations" "Data API"
check_unique_versions "$edge_migrations" "Edge"

docker run --detach --name "$container_name" \
  --env "POSTGRES_PASSWORD=$postgres_password" \
  "$postgres_image" >/dev/null

for _attempt in {1..60}; do
  if docker exec "$container_name" pg_isready --username postgres >/dev/null 2>&1; then
    break
  fi
  sleep 1
done
if ! docker exec "$container_name" pg_isready --username postgres >/dev/null 2>&1; then
  echo "Disposable PostgreSQL did not become ready" >&2
  exit 1
fi

docker exec "$container_name" psql --username postgres --set ON_ERROR_STOP=1 \
  --command "create role anon nologin; create role authenticated nologin; create role service_role nologin bypassrls;"
docker exec "$container_name" createdb --username postgres data_api_clean_boot
docker exec "$container_name" createdb --username postgres edge_clean_boot

apply_directory() {
  local database="$1"
  local directory="$2"
  local file
  while IFS= read -r file; do
    echo "Applying $(basename "$file") to $database"
    docker exec --interactive "$container_name" psql \
      --username postgres --dbname "$database" --set ON_ERROR_STOP=1 < "$file"
  done < <(find "$directory" -maxdepth 1 -type f -name '*.sql' -print | sort)
}

apply_directory data_api_clean_boot "$data_migrations"
echo "Reapplying Data API migrations to verify idempotency"
apply_directory data_api_clean_boot "$data_migrations"
docker exec --interactive "$container_name" psql \
  --username postgres --dbname data_api_clean_boot --set ON_ERROR_STOP=1 \
  < "$repository_root/backend/supabase/tests/verify_clean_boot_data_api.sql"

apply_directory edge_clean_boot "$edge_migrations"
echo "Reapplying Edge migrations to verify idempotency"
apply_directory edge_clean_boot "$edge_migrations"
docker exec --interactive "$container_name" psql \
  --username postgres --dbname edge_clean_boot --set ON_ERROR_STOP=1 \
  < "$repository_root/backend/supabase/edge_seed.sql"
docker exec --interactive "$container_name" psql \
  --username postgres --dbname edge_clean_boot --set ON_ERROR_STOP=1 \
  < "$repository_root/backend/supabase/edge_seed.sql"
docker exec --interactive "$container_name" psql \
  --username postgres --dbname edge_clean_boot --set ON_ERROR_STOP=1 \
  < "$repository_root/backend/supabase/tests/verify_clean_boot_edge.sql"
docker exec --interactive "$container_name" psql \
  --username postgres --dbname edge_clean_boot --set ON_ERROR_STOP=1 \
  < "$repository_root/backend/supabase/tests/test_atomic_edge_submissions.sql"

echo "Migration clean boot passed for Data API and optional Edge chains"
