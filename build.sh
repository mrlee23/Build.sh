#!/bin/bash

if [ -z "${GH_TOKEN}" ]; then "GH_TOKEN is not setted" 1>&2; fi
if [ -z "${REPO}" ]; then REPO=$(sed "s/https:\/\/github.com/https:\/\/${GH_TOKEN}@github.com/g" <<< $(git config remote.origin.url)); fi

COMMIT_MSG=`git log --oneline -n 1 --pretty='%s'`
COMMIT_HASH=`git log --oneline -n 1 --pretty='%h'`

CURRENT_BRANCH=`git rev-parse --abbrev-ref HEAD`

# RELEASE VARIABLES
RELEASE_BRANCH="release"
RELEASE_DIR=".release"
RELEASE_REGEXP="release[d]?.?v*"
RELEASE_VERSION_REGEXP="[0-9]+\.[0-9]+(\.[0-9]+)?"

case $1 in
	release)
		shopt -s nocasematch # case insensitive
		if [[ ! $COMMIT_MSG =~ $RELEASE_REGEXP ]]
		then
			echo "Passed to release this commit: $COMMIT_HASH"
			echo "\"$COMMIT_MSG\" is not matched with \"$RELEASE_REGEXP\""
			exit
		fi
		shopt -u nocasematch # case insensitive
		[[ $COMMIT_MSG =~ $RELEASE_VERSION_REGEXP ]] && RELEASE_VERSION="${BASH_REMATCH[0]}"
		RELEASE_DIR="${RELEASE_DIR}-$RELEASE_VERSION"
		RELEASE_COMMIT_MSG="Release version $RELEASE_VERSION from $COMMIT_HASH"
		echo "Copy to $RELEASE_DIR"
		git branch -d $RELEASE_BRANCH
		git checkout -b $RELEASE_BRANCH
		rm -rf ./$RELEASE_DIR
		rsync -avr --exclude=.git ./ ./$RELEASE_DIR/
		git pull origin $RELEASE_BRANCH 1>&2;
		rsync -avr --exclude=.git --delete ./$RELEASE_DIR/ ./
		echo "Restore from $RELEASE_DIR"
		git add ./
		git commit -a -m "$RELEASE_COMMIT_MSG"
		test $? -eq "0" && git push $REPO $RELEASE_BRANCH > /dev/null 2>&1
		git checkout $CURRENT_BRANCH
		# shopt -u extglob
		;;
	publish) ;;
esac
