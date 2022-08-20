#!/bin/bash

# This script is run on HamsterRepublic.com to update the symbolic links for the latest stable release
# This script is really just for updating the links to the newest version, or a quick rollback to the
# previous version. It can't reliably rollback to very old versions

PLAYER_ONLY=""

POSITIONAL=()
while [[ $# -gt 0 ]]; do
  key="$1"

  case $key in
    -p|--player-only)
      PLAYER_ONLY="true"
      shift # past arg
      ;;
    -h|--help)
      echo "USAGE: ./ohrstable.sh [-p] [codename]"
      echo ""
      echo "Run with no arguments to list available codenames"
      echo "Don't expect this script to work well with old codenames"
      echo "It is really just meant to switch between recent ones"
      echo ""
      echo "-p argument only updates the links for the minimal"
      echo "   player only files used by the Distribute Game feature"
      exit 0
      ;;
    *)    # unknown option
      POSITIONAL+=("$1") # save it in an array for later
      shift # past argument
      ;;
  esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

WEBROOT=~/HamsterRepublic.com
ARCHIVE="${WEBROOT}"/ohrrpgce/archive
DL="${WEBROOT}"/dl
REL="../ohrrpgce/archive"

STABLE=`
readlink "${DL}"/ohrrpgce-win-installer.exe \
  | sed -e s/".*\/"/""/ \
        -e s/"ohrrpgce-win-installer-"/""/ \
        -e s/"\.exe$"/""/ \
  | cut -d "-" -f 4- \
  `
echo "Current stable milestone is: ${STABLE}"

PLAYERSTABLE=`
readlink"${DL}"/ohrrpgce-player-linux-x86_64.zip \
  | sed -e s/".*\/"/""/ \
        -e s/"ohrrpgce-player-linux-"/""/ \
        -e s/"-x86_64\.zip$"/""/ \
  | cut -d "-" -f 4- \
  `
echo "Current stable player-only milestone is: ${PLAYERSTABLE}"

if [ -n "$PLAYER_ONLY" ] ; then
  echo "Just updating the minimal player only files..."
else
  echo "Pass -p argument if you want to only update the player links"
fi

VER="${1}"
USAGE="true"

if [ -e "$ARCHIVE"/ohrrpgce-win-installer-????-??-??-"${VER}".exe ] ; then
  unset USAGE
fi

if [ "${USAGE}" ] ; then
  if [ -z "${VER}" ] ; then
    echo "You must specify a milestone on the command-line."
  else
    echo "Milestone \"${VER}\" is not valid."
  fi
  echo "Available milestones:"
  ls -1 "${ARCHIVE}"/ohrrpgce-win-installer-*.exe \
    | sed -e s/"^.*\/ohrrpgce-win-installer-"/""/ \
          -e s/"\.exe$"/""/ \
    | sort \
    | uniq \
    | cut -d "-" -f "4-" \
    | column
  exit
fi

echo "Updating links to point to ${VER} milestone..."
cd "${DL}"

function sourcefile () {
  REL="${1}"
  PREFIX="${2}"
  VER="${3}"
  EXT="${4}"
  ls -1 "${REL}/${PREFIX}"-????-??-??-"${VER}${EXT}" \
         2>&1 \
         | grep -v ": No such file or directory" \
         | sed s/".*\/"/""/
}

function updatelink () {
  REL="${1}"
  VER="${2}"
  PREFIX="${3}"
  EXT="${4}"
  OLDPREFIX="${5}"
  OLDPREFIX2="${6}"
  DFILE="${PREFIX}${EXT}"
  printf "  ${DFILE}"
  SFILE=`sourcefile "${REL}" "${PREFIX}" "${VER}" "${EXT}"`
  if [ ! -f "${REL}/${SFILE}" ] ; then
    if [ -n "${OLDPREFIX}" ] ; then
      SFILE=`sourcefile "${REL}" "${OLDPREFIX}" "${VER}" "${EXT}"`
      if [ ! -f "${REL}/${SFILE}" ] ; then
        if [ -n "${OLDPREFIX2}" ] ; then
          SFILE=`sourcefile "${REL}" "${OLDPREFIX2}" "${VER}" "${EXT}"`
          if [ -n "${OLDPREFIX2}" ] ; then
            printf " (NONE OF 3 FOUND!)\n"
            exit
          fi
        else
          printf " (NEITHER FOUND!)\n"
          exit
        fi
      fi
    else
      printf " (NOT FOUND!)\n"
      exit
    fi
  fi
  printf " (${SFILE})"
  rm "${DFILE}"
  ln -s "${REL}/${SFILE}" "${DFILE}"
  printf "\n"
}

if [ -z "$PLAYER_ONLY" ] ; then
# Windows files
updatelink "${REL}" "${VER}" "ohrrpgce-win-installer" ".exe" "" ""
updatelink "${REL}" "${VER}" "ohrrpgce"               ".zip" "custom" ""
updatelink "${REL}" "${VER}" "ohrrpgce-win95"         ".zip" "" ""
# Reduced-size version of the full engine (which is different from ohrrpgce_play but nevermind)
updatelink "${REL}" "${VER}" "ohrrpgce-minimal"       ".zip" "ohrrpgce-floppy" "ohrrpgce_play"

# Old Mac files for versions <= etheldreme
#updatelink "${REL}" "${VER}" "OHRRPGCE"               ".dmg" "" ""
#updatelink "${REL}" "${VER}" "ohrrpgce-mac-minimal"   ".tar.gz" "" ""

# New Mac files >= fufluns
updatelink "${REL}" "${VER}" "OHRRPGCE"               "-x86_64.dmg" "" ""
updatelink "${REL}" "${VER}" "OHRRPGCE"               "-x86.dmg" "" ""

# Android files
updatelink "${REL}" "${VER}" "ohrrpgce-game-android-debug" ".apk" "" ""

# Old Linux files <= callipygous

# Theoretically you could uncomment these and comment the others if you need to roll back
# to an old stable for no plausible reason I can imagine, but that would overwrite a fixed
# symlink (see below)
#updatelink "${REL}" "${VER}" "ohrrpgce-linux-x86"     ".tar.bz2" "" ""
#updatelink "${REL}" "${VER}" "ohrrpgce-player-linux-bin-minimal" ".zip" "" ""

# New Linux files >= dwimmercrafty
updatelink "${REL}" "${VER}" "ohrrpgce-linux"     "-x86.tar.bz2" "" ""
updatelink "${REL}" "${VER}" "ohrrpgce-linux"     "-x86_64.tar.bz2" "" ""

# Source code
updatelink "${REL}" "${VER}" "ohrrpgce-source"    ".zip" "" ""
fi

# These are the files downloaded by the distrib menu
updatelink "${REL}" "${VER}" "ohrrpgce-player-win-sdl2" ".zip" "ohrrpgce-player-win-minimal-sdl2" ""
updatelink "${REL}" "${VER}" "ohrrpgce-player-win-win95" ".zip" "ohrrpgce-player-win" ""
updatelink "${REL}" "${VER}" "ohrrpgce-mac-minimal"   "-x86_64.tar.gz" "" ""
updatelink "${REL}" "${VER}" "ohrrpgce-mac-minimal"   "-x86.tar.gz" "" ""
updatelink "${REL}" "${VER}" "ohrrpgce-player-linux"  "-x86.zip" "" ""
updatelink "${REL}" "${VER}" "ohrrpgce-player-linux"  "-x86_64.zip" "" ""

# Static symlinks that exist on the server to support the distrib menu in obsolete versions:
# For gorgonzola and older (require music_sdl build)
# ohrrpgce-player-win.zip -> ohrrpgce-player-win-win95.zip
# For hróðvitnir
# ohrrpgce-player-win-minimal-sdl2.zip -> ohrrpgce-player-win-sdl2.zip
# For etheldreme and older
# ohrrpgce-mac-minimal.tar.gz -> ohrrpgce-mac-minimal-x86_64.tar.gz
# For callipygous and older
# ohrrpgce-player-linux-bin-minimal.zip -> ohrrpgce-player-linux-bin-minimal-x86.zip
