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
      echo "-p argument only updates the links for the player-only files"
      echo "   (previously used by the Distribute Game feature in hróðvitnir and older)"
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
readlink "${DL}"/ohrrpgce-source.zip \
  | sed -e s/".*\/"/""/ \
        -e s/"ohrrpgce-source-"/""/ \
        -e s/"\.zip$"/""/ \
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

# If a file with this pattern exists, print its filename.
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

# Try each PREF of PREFIX, OLDPREFIX, OLDPREFIX2, until finding a matching file,
# then create a a link ${PREF}${EXT} to ${REL}${PREF}-date-${VER}${EXT}.
function updatelink () {
  REL="${1}"
  VER="${2}"
  PREFIX="${3}"
  EXT="${4}"
  OLDPREFIX="${5}"
  OLDPREFIX2="${6}"
  printf "  Looking for ${PREFIX}${EXT} (or variant)"
  SFILE=`sourcefile "${REL}" "${PREFIX}" "${VER}" "${EXT}"`
  if [ -f "${REL}/${SFILE}" ] ; then
    DFILE="${PREFIX}${EXT}"
  else
    if [ -n "${OLDPREFIX}" ] ; then
      SFILE=`sourcefile "${REL}" "${OLDPREFIX}" "${VER}" "${EXT}"`
      if [ -f "${REL}/${SFILE}" ] ; then
        DFILE="${OLDPREFIX}${EXT}"
      else
        if [ -n "${OLDPREFIX2}" ] ; then
          SFILE=`sourcefile "${REL}" "${OLDPREFIX2}" "${VER}" "${EXT}"`
          if [ -f "${REL}/${SFILE}" ] ; then
            DFILE="${OLDPREFIX2}${EXT}"
          else
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
  printf " ${DFILE}  ->  ${SFILE}"
  rm "${DFILE}"
  ln -s "${REL}/${SFILE}" "${DFILE}"
  printf "\n"
}

if [ -z "$PLAYER_ONLY" ] ; then
# Windows files
updatelink "${REL}" "${VER}" "ohrrpgce-win-installer" ".exe" "" ""
updatelink "${REL}" "${VER}" "ohrrpgce-win"           ".zip" "ohrrpgce" "custom"
updatelink "${REL}" "${VER}" "ohrrpgce-win"           "-win95.zip" "" ""
updatelink "${REL}" "${VER}" "ohrrpgce-win"           "-minimal.zip" "" ""

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

# Player-only packages. These are downloaded by the distrib menu in hróðvitnir and older
# versions. Since ichorescent, the distrib menu downloads the correct file from
# http://hamsterrepublic.com/ohrrpgce/archive/ instead, and the only reason
# to update these is for linking to from the website... although we don't yet.
updatelink "${REL}" "${VER}" "ohrrpgce-player-win"    "-sdl2.zip" "" ""
updatelink "${REL}" "${VER}" "ohrrpgce-player-win"    "-win95.zip" "" ""
# hróðvitnir and older
#updatelink "${REL}" "${VER}" "ohrrpgce-player-win-sdl2" ".zip" "ohrrpgce-player-win-minimal-sdl2" "ohrrpgce-player-win"
updatelink "${REL}" "${VER}" "ohrrpgce-player-mac"    "-x86.tar.gz"    "ohrrpgce-mac-minimal" ""
updatelink "${REL}" "${VER}" "ohrrpgce-player-mac"    "-x86_64.tar.gz" "ohrrpgce-mac-minimal" ""
updatelink "${REL}" "${VER}" "ohrrpgce-player-linux"  "-x86.zip"    "ohrrpgce-player-linux-bin-minimal" ""
updatelink "${REL}" "${VER}" "ohrrpgce-player-linux"  "-x86_64.zip" "ohrrpgce-player-linux-bin-minimal" ""


# These are the symlinks in http://hamsterrepublic.com/ohrrpgce/dl that are left over from obsolete
# versions to support the distrib menu:
#   For hróðvitnir and older
# ohrrpgce-player-win-minimal-sdl2.zip           -> ohrrpgce-player-win-minimal-sdl2-2021-09-13-hrodvitnir.zip
# ohrrpgce-mac-minimal-x86[_64].tar.gz           -> ohrrpgce-linux-2021-09-13-hrodvitnir-x86[_64].tar.bz2
# ohrrpgce-player-linux-bin-minimal-x86[_64].zip -> ohrrpgce-player-linux-bin-minimal-2021-09-13-hrodvitnir-x86[_64].zip
#   For gorgonzola and older (require gfx_directx+sdl[+fb]/music_sdl build)
# ohrrpgce-player-win.zip                        -> ohrrpgce-player-win-2020-05-02-gorgonzola.zip
#   For etheldreme and older
# ohrrpgce-mac-minimal.tar.gz                    -> ohrrpgce-mac-minimal-2017-12-03-etheldreme.tar.gz
#   For callipygous and older
# ohrrpgce-player-linux-bin-minimal.zip          -> ohrrpgce-player-linux-bin-minimal-2016-06-06-callipygous+1.zip
#   For alectormancy+1/2
# ohrrpgce-mac-minimal-linkless.tar.gz  (not a symlink)
