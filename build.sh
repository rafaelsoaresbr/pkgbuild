#/usr/bin/sh

basedir="$(cd "$(dirname "$0")"; pwd)"

chroot="$basedir/chroot"

exists() {
  command -v "$1" >/dev/null 2>&1
}

built(){
  if (exists arch-nspawn); then
    arch-nspawn "$chroot/$reponame" pacman -Q "$1" > /dev/null 2>&1
  else
    pacman -Q "$1" > /dev/null 2>&1
  fi
}

find_deps() {
  (
  set -e
  cmd < "${basedir}/$1/$2/.SRCINFO" | sed -nr 's/^\W*depends = ([-a-zA-Z0-9]+).*$/\1/p' | while read -r dep; do
    if [ -d "$basedir/$1/$dep" ]; then
      echo $"{dep}"
    fi
  done
  )
}

build() {
  (
  set -e
  packagename=$2
  packagedir=$basedir/$1/$2
  if [ ! -f "$packagedir/PKGBUILD" ]; then
    echo "Cannot find PKGBUILD in $packagedir"
    return 1
  fi
  if built $pkgname; then
    echo "Package $packagename already built"
    return
  fi
  if [ ! -f "$packagedir/.SRCINFO" ]; then
    mksrcinfo
  fi
  find_deps "$1" "$packagename" | while read -r dep; do
    if built $dep; then
      build "$1" "$dep"
    fi
  done
  cd "$packagedir"
  mksrcinfo
  rm -f ./*.pkg.tar.xz
  mkdir -p "$basedir/pkg"
  makechrootpkg -r "$chroot" -l "$reponame" -- -i
  mv ./*.pkg.tar.xz "$basedir/pkg"
  )
}

if (exists mkarchroot) && [ ! -d "$chroot" ]; then
  mkdir "$chroot"
  mkarchroot "$chroot/root" base-devel
fi

if [ "$#" -lt 2 ]; then
  # Build all packages from a repository (defaulting to aur)
  cd "$basedir/${1:-aur}"
  find -type d | sed 's/\.\///' | tail -n +2 | while read -r pkg; do
    build "${1:-aur}" "$pkg"
  done
else
  # Build only requested packages
  reponame=$1
  for pkg in "$@:2"; do
    build "$reponame" "$pkg"
  done
fi
