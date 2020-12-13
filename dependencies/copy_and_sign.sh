#!/bin/zsh

# written by ronbb

installPrefix=@executable_path/../Frameworks

localLibDir=/usr/local/lib

localIncDir=/usr/local/include

localLibRegex="/usr/local/\S*\.dylib"

libRegex="([^/]+)\w+\.dylib$"

libOutDir=./library

incOutDir=./include

targets=(avcodec avdevice avfilter avformat avresample avutil postproc swresample swscale)

targetLibs=()

typeset -A deps=()
typeset -A libs=()

clean() {
  echo "clean include & library"
  rm -rf ${libOutDir}
  rm -rf ${incOutDir}
}

createDir() {
  echo create dir
  mkdir ${libOutDir}
  mkdir ${incOutDir}
}

realpath() {
  local target=$1
  local tmp=""

  [ -f "$target" ] || return 1

  while true; do
    tmp="$(readlink "$target")" 
    if [[ $? -eq 0 ]]; then
      if [[ $tmp =~ "^[^/]" ]]; then
        tmp="$(dirname ${target})/${tmp}"
      fi
      target=$tmp
    else
      break
    fi
  done

  echo $target
  return 0
}   

findTargets() {
  for target in ${targets[*]}; do
    targetLibs+=$(realpath ${localLibDir}/lib${target}.dylib)
  done
}

findDeps() {
  oIFS=$IFS
  IFS=$'\n\n'

  long=$(realpath $1)
  short=$(echo $long | grep -Eo "${libRegex}")
  libs[$short]=$long
  deps[$short]='true'

  for dep in $(otool -L $long); do
    long=$(echo $dep | grep -Eo "${localLibRegex}")
    if [ -z ${long} ]; then
      continue
    fi
    long=$(realpath ${long})

    short=$(echo $long | grep -Eo "${libRegex}")
    libs[$short]=$long
    
    if [[ ${deps[$short]} == 'true' ]]; then
      continue
    else
      deps[${short}]='false'
    fi
  done

  IFS=$oIFS
}

checkDeps() {
  for found in ${deps[*]}; do
    if [[ $found == 'false' ]]; then
     return 1
    fi
  done
  return 0
}

findAllDeps() {
  for targetLib in ${targetLibs[*]}; do
    findDeps $targetLib
  done

  while true
  do
    checkDeps
    if [[ $? == 0 ]]; then
      break
    fi
    for dep in ${(k)deps[*]}; do
      found=${deps[$dep]}
      if [[ $found == 'false' ]]; then
        findDeps $libs[$dep]
      fi
    done
  done
}

copyDeps() {
  echo copy deps ${#libs[*]}
  for file in ${(k)libs[*]}; do
    cp -p $libs[$file] ${libOutDir}/${file}
  done
}

copyIncs() {
  echo copy include
  for target in ${targets[*]}; do
    inc=${localIncDir}/lib${target}
    cp -p -r $inc ${incOutDir}/lib${target}
  done
}

changeInstallName() {
  echo change install name
  for file in ${(k)libs[*]};do
    lib=${libOutDir}/${file}
    install_name_tool -id ${installPrefix}/${file} $lib

    oIFS=$IFS
    IFS=$'\n\n'

    for dep in $(otool -L $lib); do
      long=$(echo $dep | grep -Eo "${localLibRegex}")
      if [ -z ${long} ]; then
        continue
      fi
      short=$(echo $(realpath $long)| grep -Eo "${libRegex}")
      install_name_tool -change $long ${installPrefix}/${short} $lib
    done

    deps[$lib]='true'

    IFS=$oIFS
  done
}

codeSign() {
  echo code sign
  codesign -f -s "Apple Development: ronbiaobiao@vip.qq.com" ${libOutDir}/*.dylib
}

clean

createDir

copyIncs

findTargets

findAllDeps

copyDeps

changeInstallName

codeSign
