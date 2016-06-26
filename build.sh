#/usr/bin/sh

build () {
  echo Building ${2}
  cd ${1}/${2}
  makepkg -f -d --noarchive --noconfirm --noprogressbar
  cd ../../
}

for i in $(git diff --name-only --relative=${1} HEAD^ HEAD | cut -f1 -d'/' | sort -u);
do
  build ${1} ${i}
done
