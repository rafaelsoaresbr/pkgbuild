#/usr/bin/bash

basedir="$PWD"
reponame="${1:-aur}"

find_deps() {
  (
  set -e
  cd "$basedir/$reponame/$1"
  cmd < "$(cd "$basedir/$reponame/$1" makepkg --printsrcinfo)" | sed -nr 's/^\W*depends = ([-a-zA-Z0-9]+).*$/\1/p' | while read -r dep; do
    for pkg in ${pkgs[@]}; do
      cmd < "$(cd "$packagedir" && makepkg --printsrcinfo)" | sed -nr 's/^\W*pkgname = ([-a-zA-Z0-9]+).*$/\1/p' | while read -r package_name; do
        if [ "$dep" == "$package_name" ]; then
          echo "$pkg"
        fi
      done
    done
  done
  )
}

build() {
  (
  set -e
  packagename="$1"
  packagedir="$basedir/$reponame/$packagename"
  if [ ! -f "$packagedir/PKGBUILD" ]; then
    echo "Cannot find PKGBUILD in $packagedir"
    return 1
  fi
  find_deps "$packagename" | while read -r dep; do
    build "$dep"
  done
  cd "$packagedir"
  makepkg -si --noconfirm --noprogressbar
  )
}

if [ "$#" -lt 2 ]; then
  # Build all packages from a repository (defaulting to aur)
  pkgs=( $(cd "$basedir/$reponame" && find -- * -prune -type d | tr '\n' ' ') )
  for pkg in ${pkgs[@]}; do
    build "$pkg"
  done
else
  # Build only requested packages
  for pkg in "${@:2}"; do
    build "$pkg"
  done
fi
