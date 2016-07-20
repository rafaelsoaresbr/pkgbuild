#/usr/bin/sh

basedir=$(cd $(dirname $0); pwd)

chroot="${basedir}/chroot"

find_deps() {
  (
  set -e
  cat ${basedir}/${1}/${2}/.SRCINFO | sed -nr 's/^\W*depends = ([-a-zA-Z0-9]+).*$/\1/p' | while read dep; do
    if [ -d ${basedir}/${1}/${basedir}/${dep} ]; then
      echo $dep
    fi
  done
  )
}

build() {
  (
  set -e
  packagename=${2}
  packagedir=${basedir}/${1}/${2}
  if (arch-nspawn $chroot/build pacman -Q $package_name > /dev/null 2>&1); then
	    echo "Package $packagename already built"
	    return
	fi
  find_deps ${1} ${packagename} | while read dep; do
    if !(arch-nspawn ${chroot}/build pacman -Q $dep > /dev/null 2>&1); then
      build ${1} $dep
    fi
  done
  cd ${packagedir}
  mksrcinfo
  rm -f *.pkg.tar.xz
  mkdir -p "${basedir}/pkg"
  makechrootpkg -r ${chroot} -l build -- -i
  mv *.pkg.tar.xz "${basedir}/pkg"
  )
}

if [ ! -d "${chroot}" ]; then
  mkdir "${chroot}"
  mkarchroot "${chroot}/root" base-devel
fi

cd $basedir/${1:-aur}
find -type d | sed 's/\.\///' | tail -n +2 | while read pkg; do
  package_build ${1:-aur} $pkg
done
