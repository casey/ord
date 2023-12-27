#!/usr/bin/env bash

set -euo pipefail

if [[ -n ${GITHUB_ACTIONS-} ]]; then
  set -x
fi

# Display help message
help() {
  cat <<'EOF'
Install a binary release of ord hosted on GitHub

USAGE:
    install.sh [options]

FLAGS:
    -h, --help      Display this message
    -f, --force     Force overwriting an existing binary

OPTIONS:
    --tag TAG       Tag (version) of the crate to install, defaults to latest release
    --to LOCATION   Where to install the binary [default: ~/bin]
    --target TARGET Specify the installation target explicitly
EOF
}

# Define required commands
check_dependencies() {
  local commands=("curl" "install" "mkdir" "mktemp" "tar" "cut")
  for cmd in "${commands[@]}"; do
    command -v "$cmd" > /dev/null 2>&1 || {
      echo "Error: $cmd is required but not found." >&2
      exit 1
    }
  done
}

# Check and install dependencies
check_dependencies

# Set default variables
crate="ord"
url="https://github.com/ordinals/ord"
releases="$url/releases"
force=false
dest="${HOME}/bin"

# Parse command line options
while [[ $# -gt 0 ]]; do
  case $1 in
    --force | -f)
      force=true
      ;;
    --help | -h)
      help
      exit 0
      ;;
    --tag)
      tag=$2
      shift
      ;;
    --target)
      target=$2
      shift
      ;;
    --to)
      dest=$2
      shift
      ;;
    *)
      ;;
  esac
  shift
done

# Fetch the latest tag if not specified
if [[ -z ${tag-} ]]; then
  tag=$(curl --proto =https --tlsv1.2 -sSf "${releases}/latest" | grep -oP '"tag_name": "\K(.*)(?=")')
fi

# Determine the target architecture
if [[ -z ${target-} ]]; then
  uname_target=$(uname -m)-$(uname -s)

  case $uname_target in
    arm64-Darwin) target=aarch64-apple-darwin;;
    x86_64-Darwin) target=x86_64-apple-darwin;;
    x86_64-Linux) target=x86_64-unknown-linux-gnu;;
    *)
      echo "Error: Unsupported architecture $uname_target."
      echo "Consider using --target flag to specify the target explicitly."
      exit 1
      ;;
  esac
fi

archive="${releases}/download/${tag}/${crate}-${tag}-${target}.tar.gz"

# Display installation details
echo "Repository:  $url"
echo "Crate:       $crate"
echo "Tag:         $tag"
echo "Target:      $target"
echo "Destination: $dest"
echo "Archive:     $archive"

# Create a temporary directory
tempdir=$(mktemp -d || mktemp -d -t tmp)

# Download and install the binary
curl --proto =https --tlsv1.2 -sSfL "$archive" | tar --directory "$tempdir" --strip-components 1 -xz

# Install the binary
for file in "$tempdir"/*; do
  if [[ -x $file ]]; then
    name=$(basename "$file")
    if [[ -e "${dest}/${name}" && $force = false ]]; then
      echo "Error: $name already exists in $dest."
      exit 1
    else
      mkdir -p "$dest" && install -m 755 "$file" "$dest"
    fi
  fi
done

# Clean up temporary directory
rm -rf "$tempdir"
