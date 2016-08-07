#/usr/bin/bash

basedir="$PWD"
chroot="$basedir/chroot"
reponame="${1:-aur}"

exists() {
  (
  set -e
  command -v "$1" >/dev/null 2>&1
  )
}

built(){
  (
  set -e
  if (exists arch-nspawn); then
    arch-nspawn "$chroot/$reponame" pacman -Q "$1" > /dev/null 2>&1
  else
    pacman -Q "$1" > /dev/null 2>&1
  fi
  )
}

find_deps() {
  (
  set -e
  cd "$basedir/$reponame/$1"
  cmd < "$(makepkg --printsrcinfo)" | sed -nr 's/^\W*depends = ([-a-zA-Z0-9]+).*$/\1/p' | while read -r dep; do
    if [ -d "$basedir/$reponame/$dep" ]; then
      echo "$dep"
    fi
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
  if built "$packagename"; then
    echo "Package $packagename already built"
    return
  fi
  if [ ! -f "$packagedir/.SRCINFO" ]; then
    makepkg --printsrcinfo > "$packagedir/.SRCINFO"
  fi
  find_deps "$packagename" | while read -r dep; do
    if built "$dep"; then
      build "$dep"
    fi
  done
  mkdir -p "$basedir/pkg"
  cd $packagedir
  if (exists mkarchroot); then
    makechrootpkg -r "$chroot" -l "$reponame" -- -i
    mv ./*.pkg.tar.xz "$basedir/pkg"
  else
    makepkg -s --noconfirm --noprogressbar
  fi
  )
}

if (exists mkarchroot) && [ ! -d "$chroot" ]; then
  mkdir "$chroot"
  mkarchroot "$chroot/root" base-devel
fi

if [ "$#" -lt 2 ]; then
  # Build all packages from a repository (defaulting to aur)
  cd "$basedir/$reponame"
  find -type d | sed 's/\.\///' | tail -n +2 | while read -r pkg; do
    build "$pkg"
  done
else
  # Build only requested packages
  for pkg in "${@:2}"; do
    build "$pkg"
  done
fi
