#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

HELP_DIR="${ROOT_DIR}/help"
BIN_DIR="${HOME}/bin"

if [[ ! -d "${HELP_DIR}" ]]; then
  echo "No help/ directory found."
  exit 0
fi

all_help_dirs=()
while IFS= read -r line; do
  all_help_dirs+=("$line")
done < <(find "${HELP_DIR}" -mindepth 1 -maxdepth 1 -type d -print)

if [[ ${#all_help_dirs[@]} -eq 0 ]]; then
  echo "No help CLIs to deploy."
  exit 0
fi

changed_dirs=()

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  changed_files=()
  while IFS= read -r line; do
    changed_files+=("$line")
  done < <(
    {
      git diff --name-only -- "${HELP_DIR}" || true
      git diff --name-only --cached -- "${HELP_DIR}" || true
      git ls-files --others --exclude-standard -- "${HELP_DIR}" || true
    } | sort -u
  )

  if [[ ${#changed_files[@]} -gt 0 ]]; then
    changed_dirs=()
    while IFS= read -r line; do
      changed_dirs+=("$line")
    done < <(
      printf "%s\n" "${changed_files[@]}" \
        | awk -F/ 'NF>=2 {print $2}' \
        | sort -u
    )
  fi
else
  changed_dirs=()
  while IFS= read -r line; do
    changed_dirs+=("$line")
  done < <(find "${HELP_DIR}" -mindepth 1 -maxdepth 1 -type d -print)
  for i in "${!changed_dirs[@]}"; do
    changed_dirs[$i]="$(basename -- "${changed_dirs[$i]}")"
  done
fi

if [[ ${#changed_dirs[@]} -eq 0 ]]; then
  echo "No changed help CLIs detected."
  exit 0
fi

mkdir -p "${BIN_DIR}"

deploy_one() {
  local name="$1"
  local dir="${HELP_DIR}/${name}"
  local pkg="${dir}/moon.pkg.json"
  if [[ ! -f "${pkg}" ]]; then
    return 0
  fi

  echo "Building help/${name}..."
  moon build "help/${name}" --target native -q

  local build_dir="${ROOT_DIR}/_build/native/release/build/help/${name}"
  local source_bin="${build_dir}/${name}.exe"
  if [[ ! -f "${source_bin}" ]]; then
    echo "Error: Binary not found at ${source_bin}"
    return 1
  fi

  local bin_name="${name}-help"
  cp -f "${source_bin}" "${BIN_DIR}/${bin_name}"
  chmod +x "${BIN_DIR}/${bin_name}"
  echo "Installed ${bin_name} to ${BIN_DIR}/${bin_name}"
}

for name in "${changed_dirs[@]}"; do
  deploy_one "${name}"
done

case ":${PATH}:" in
  *:"${BIN_DIR}":*) ;;
  *)
    echo ""
    echo "Note: ${BIN_DIR} is not on PATH."
    echo "Add with: fish_add_path ${BIN_DIR}"
    ;;
esac
