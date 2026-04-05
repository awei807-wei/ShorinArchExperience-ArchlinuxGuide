#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
src_root="${HOME}/.config"
dst_root="${repo_root}/dotfiles/.config"
allowlist="${dst_root}/.backup-allowlist"
excludes="${dst_root}/.backup-excludes"

if [[ ! -f "${allowlist}" || ! -f "${excludes}" ]]; then
  echo "缺少清单文件: ${allowlist} 或 ${excludes}" >&2
  exit 1
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

filter_list() {
  local file="$1"
  awk '
    /^[[:space:]]*#/ { next }
    /^[[:space:]]*$/ { next }
    { print }
  ' "${file}"
}

allowlist_file="${tmpdir}/allowlist.txt"
filter_list "${allowlist}" > "${allowlist_file}"

exclude_args=()
while IFS= read -r pattern; do
  exclude_args+=(--exclude="${pattern}")
done < <(filter_list "${excludes}")

printf '仓库根目录: %s\n' "${repo_root}"
printf '源目录: %s\n' "${src_root}"
printf '目标目录: %s\n' "${dst_root}"
printf '\n'

printf '顶层白名单:\n'
sed 's/^/  - /' "${allowlist_file}"
printf '\n'

printf '同步预演结果:\n'
while IFS= read -r entry; do
  [[ -e "${src_root}/${entry}" || -L "${src_root}/${entry}" ]] || {
    printf '  ! 缺失: %s\n' "${entry}"
    continue
  }

  printf '\n[%s]\n' "${entry}"
  rsync -ani \
    "${exclude_args[@]}" \
    "${src_root}/${entry}" \
    "${dst_root}/" \
    | sed 's/^/  /'
done < "${allowlist_file}"
