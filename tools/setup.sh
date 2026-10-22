#!/usr/bin/env bash
#
# Set up an isolated, project-local toolchain (Ruby + Bundler + Jekyll + Node/npm)
# in ./.venv so the site can be rendered locally without touching the system.
#
# Usage:
#   bash tools/setup.sh            # install everything into .venv
#   source .venv/bin/activate      # use the toolchain in the current shell
#   bash tools/run.sh              # serve the site (after activating)
#   deactivate                     # leave the environment

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV="$ROOT/.venv"

RUBY_SERIES="${RUBY_SERIES:-3.4}" # keep in sync with .github/workflows/pages-deploy.yml
NODE_SERIES="${NODE_SERIES:-24}"  # Node LTS line

LIBYAML_VERSION="0.2.5"

RUBY_BUILD_DIR="$VENV/src/ruby-build"
DEPS_PREFIX="$VENV/deps"
RUBY_PREFIX="$VENV/ruby"
NODE_PREFIX="$VENV/node"
BUNDLE_DIR="$VENV/bundle"

log() { echo -e "\n\033[1;34m==>\033[0m $*"; }

check_prereqs() {
  if [[ "$(uname)" == "Darwin" ]] && ! xcode-select -p &>/dev/null; then
    echo "Xcode Command Line Tools are required: run 'xcode-select --install'" >&2
    exit 1
  fi
  for cmd in git curl tar make; do
    command -v "$cmd" &>/dev/null || {
      echo "Missing required command: $cmd" >&2
      exit 1
    }
  done
}

# libyaml is needed for Ruby's psych (YAML) extension, which Jekyll depends on
install_libyaml() {
  if [[ -f "$DEPS_PREFIX/include/yaml.h" ]]; then
    return
  fi

  log "Building libyaml $LIBYAML_VERSION into .venv/deps"
  local tmp
  tmp="$(mktemp -d)"
  curl -fsSL "https://github.com/yaml/libyaml/releases/download/$LIBYAML_VERSION/yaml-$LIBYAML_VERSION.tar.gz" |
    tar -xz -C "$tmp" --strip-components 1
  (cd "$tmp" && ./configure --prefix="$DEPS_PREFIX" --disable-dependency-tracking >/dev/null && make -s -j4 install >/dev/null)
  rm -rf "$tmp"
}

install_ruby() {
  if [[ -x "$RUBY_PREFIX/bin/ruby" ]]; then
    log "Ruby already installed: $("$RUBY_PREFIX/bin/ruby" -v)"
    return
  fi

  log "Fetching ruby-build (project-local)"
  if [[ -d "$RUBY_BUILD_DIR/.git" ]]; then
    git -C "$RUBY_BUILD_DIR" pull --quiet
  else
    mkdir -p "$(dirname "$RUBY_BUILD_DIR")"
    git clone --quiet --depth 1 https://github.com/rbenv/ruby-build.git "$RUBY_BUILD_DIR"
  fi

  local version
  version="$("$RUBY_BUILD_DIR/bin/ruby-build" --definitions |
    grep -E "^${RUBY_SERIES//./\\.}\.[0-9]+$" | sort -V | tail -1)"
  [[ -n "$version" ]] || {
    echo "No Ruby $RUBY_SERIES.x definition found" >&2
    exit 1
  }

  install_libyaml

  log "Compiling Ruby $version into .venv/ruby (takes a few minutes)"
  local opts=(--with-libyaml-dir="$DEPS_PREFIX")
  if command -v brew &>/dev/null && brew --prefix openssl@3 &>/dev/null; then
    opts+=(--with-openssl-dir="$(brew --prefix openssl@3)")
  fi
  RUBY_CONFIGURE_OPTS="${opts[*]:-} --disable-install-doc" \
    MAKE_OPTS="-j$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)" \
    "$RUBY_BUILD_DIR/bin/ruby-build" "$version" "$RUBY_PREFIX"
}

install_node() {
  if [[ -x "$NODE_PREFIX/bin/node" ]]; then
    log "Node already installed: $("$NODE_PREFIX/bin/node" -v)"
    return
  fi

  local os arch
  case "$(uname)" in
  Darwin) os=darwin ;;
  Linux) os=linux ;;
  *) echo "Unsupported OS: $(uname)" >&2 && exit 1 ;;
  esac
  case "$(uname -m)" in
  arm64 | aarch64) arch=arm64 ;;
  x86_64) arch=x64 ;;
  *) echo "Unsupported arch: $(uname -m)" >&2 && exit 1 ;;
  esac

  local base="https://nodejs.org/dist/latest-v${NODE_SERIES}.x"
  local shasums tarball
  shasums="$(curl -fsSL "$base/SHASUMS256.txt")"
  tarball="$(awk -v p="-${os}-${arch}.tar.gz" '$2 ~ p"$" {print $2}' <<<"$shasums" | head -1)"
  [[ -n "$tarball" ]] || {
    echo "No Node $NODE_SERIES tarball for $os-$arch" >&2
    exit 1
  }

  log "Downloading $tarball into .venv/node"
  local tmp
  tmp="$(mktemp -d)"
  curl -fsSL "$base/$tarball" -o "$tmp/$tarball"
  (cd "$tmp" && grep " $tarball\$" <<<"$shasums" | shasum -a 256 -c - >/dev/null)
  mkdir -p "$NODE_PREFIX"
  tar -xzf "$tmp/$tarball" -C "$NODE_PREFIX" --strip-components 1
  rm -rf "$tmp"
}

write_activate() {
  log "Writing .venv/bin/activate"
  mkdir -p "$VENV/bin"
  cat >"$VENV/bin/activate" <<'EOF'
# Source this file to use the project-local toolchain:  source .venv/bin/activate
if [ -n "${_JTN_VENV:-}" ]; then deactivate; fi

_JTN_VENV="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")/.." && pwd)"
_JTN_OLD_PATH="$PATH"
_JTN_OLD_PS1="${PS1:-}"
_JTN_OLD_GEM_HOME="${GEM_HOME-__unset__}"
_JTN_OLD_GEM_PATH="${GEM_PATH-__unset__}"

export GEM_HOME="$_JTN_VENV/gems"
export GEM_PATH="$GEM_HOME"
export BUNDLE_PATH="$_JTN_VENV/bundle"
export BUNDLE_APP_CONFIG="$_JTN_VENV/bundle-config"
export BUNDLE_GEMFILE="$_JTN_VENV/../Gemfile"
export npm_config_prefix="$_JTN_VENV/node"
export PATH="$_JTN_VENV/ruby/bin:$_JTN_VENV/node/bin:$GEM_HOME/bin:$PATH"
export PS1="(.venv) ${PS1:-}"

deactivate() {
  export PATH="$_JTN_OLD_PATH"
  export PS1="$_JTN_OLD_PS1"
  if [ "$_JTN_OLD_GEM_HOME" = "__unset__" ]; then unset GEM_HOME; else export GEM_HOME="$_JTN_OLD_GEM_HOME"; fi
  if [ "$_JTN_OLD_GEM_PATH" = "__unset__" ]; then unset GEM_PATH; else export GEM_PATH="$_JTN_OLD_GEM_PATH"; fi
  unset BUNDLE_PATH BUNDLE_APP_CONFIG BUNDLE_GEMFILE npm_config_prefix
  unset _JTN_VENV _JTN_OLD_PATH _JTN_OLD_PS1 _JTN_OLD_GEM_HOME _JTN_OLD_GEM_PATH
  unset -f deactivate
  hash -r 2>/dev/null || true
}

hash -r 2>/dev/null || true
EOF
}

install_gems() {
  # shellcheck disable=SC1091
  source "$VENV/bin/activate"

  log "Installing Bundler"
  gem install bundler --no-document --conservative

  log "Installing site gems (Jekyll, Chirpy, html-proofer) into .venv/bundle"
  bundle install --jobs 4

  if [[ -f "$ROOT/package.json" ]]; then
    log "Installing npm packages"
    (cd "$ROOT" && npm install)
  fi
}

main() {
  check_prereqs
  mkdir -p "$VENV"
  install_ruby
  install_node
  write_activate
  install_gems

  log "Done.
    ruby:   $(ruby -v)
    bundle: $(bundle -v)
    jekyll: $(bundle exec jekyll -v)
    node:   $(node -v)  npm: $(npm -v)

  Next:
    source .venv/bin/activate
    bash tools/run.sh"
}

main "$@"
