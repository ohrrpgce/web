#!/bin/bash

# This assumes that we aren't using this particular copy for dev, we treat it as read-only
# and we just pull new commits on the branch

WORKING_COPY=${WORKING_COPY:-~/src/ohrcron/ohr-git-mail}
BRANCH=${BRANCH:-wip}

SCRIPTDIR="${0%/*}"
LOGFILE="$SCRIPTDIR/git-mail-$BRANCH.log"

if [ -n "always" ] ; then
echo "--------"
date "+%Y-%m-%d %H:%M:%S"

# The smtp_config.sh file can override these variables, and must override PASSWD
MAILFROM=cron@rpg.hamsterrepublic.com
MAILTO=ohrrpgce@lists.motherhamster.org
SMTP="smtps://smtp.dreamhost.com:465"
USERNAME="cron@rpg.hamsterrepublic.com"
PASSWD="*REDACTED*"

source "$SCRIPTDIR/smtp_config.sh"

if [ ! -d "$WORKING_COPY" ] ; then
  echo "Working copy $WORKING_COPY doesn't exist yet, you should create it manually before running this script"
  exit 1
fi

cd "$WORKING_COPY"
git fetch origin "$BRANCH" || exit 1
git checkout "$BRANCH" || exit 1

OLD_COMMIT=$(git log | head -1 | cut -d " " -f 2)
git pull origin "$BRANCH" --rebase
NEW_COMMIT=$(git log | head -1 | cut -d " " -f 2)

DIFFLOG=$(git log --stat ${OLD_COMMIT}...${NEW_COMMIT})

if [ -z "$DIFFLOG" ] ; then
  echo "No changes"
else

  #Split commits
  MAILNUM=1
  printf "$DIFFLOG\x00" | sed  's/^commit /\x00commit /g' | while IFS= read -r -d '' CHUNK ; do

    if [ "$CHUNK" = "" ] ; then
      # The first chunk will always be empty
      continue
    fi

    SVNREV=$(echo "$CHUNK" | sed -n -E -e '/git-svn-id:/ s/.*@([0-9]+).*/\1/p')
    SUBJECT=$(echo "$CHUNK" | grep "^ " | tr -s " " | grep -v "^ $" | head -1)

    echo "From: $MAILFROM" > "$SCRIPTDIR/git-mail.txt"
    echo "To: $MAILTO" >> "$SCRIPTDIR/git-mail.txt"
    echo "Reply-To: $MAILTO" >> "$SCRIPTDIR/git-mail.txt"
    echo "Subject: $BRANCH r$SVNREV:$SUBJECT" >> "$SCRIPTDIR/git-mail.txt"
    echo "" >> "$SCRIPTDIR/git-mail.txt"
    echo "$CHUNK" | sed -E -e 's_^commit (\S+)_https://github.com/ohrrpgce/ohrrpgce/commit/\1_' | grep -v "git-svn-id:" >> "$SCRIPTDIR/git-mail.txt"

    echo "$MAILNUM Sending mail to $MAILTO -- $SUBJECT"

    curl $SMTP -s -S \
      --mail-from $MAILFROM \
      --mail-rcpt $MAILTO \
      --ssl --ssl-reqd \
      -u "$USERNAME":"$PASSWD" \
      --upload-file "$SCRIPTDIR/git-mail.txt"

    MAILNUM=$(expr "$MAILNUM" + 1)

  done
  
fi

fi 2>&1 | tee "$LOGFILE"
