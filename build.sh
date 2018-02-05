#!/bin/bash

if [ -z "${GH_TOKEN}" ]; then "GH_TOKEN is not setted" 1>&2; fi
if [ -z "${REPO}" ]; then REPO=$(sed "s/https:\/\/github.com/https:\/\/${GH_TOKEN}@github.com/g" <<< $(git config remote.origin.url)); fi

COMMIT_MSG=`git log --oneline -n 1 --pretty='%s'`
COMMIT_HASH=`git log --oneline -n 1 --pretty='%h'`

CURRENT_BRANCH=`git rev-parse --abbrev-ref HEAD`

BRANCH_COMMIT () {
	BRANCH=$1
	COMMIT_MESSAGE=$2
	TMP_DIR=$3
	if [ -z "$BRANCH" ]; then echo "Branch does not specified."; exit 127; fi
	if [ -z "$COMMIT_MESSAGE" ]; then echo "Message does not specified."; exit 127; fi
	if [ -z "$TMP_DIR" ]; then TMP_DIR=".${BRANCH}_tmp"; fi

	echo "Copy to $TMP_DIR"
	git branch -D $BRANCH
	git checkout --orphan $BRANCH
	rm -rf ./$TMP_DIR
	rsync -avr --exclude=.git ./ ./$TMP_DIR/ # copy master to branch's tmp directory
	git pull origin $BRANCH 1>&2;
	
	echo "Restore from $TMP_DIR"
	rsync -avr --exclude=.git --delete ./$TMP_DIR/ ./ # mv branch's tmp directory to branch and remove anothers.
	
	echo "Commit..."
	git add ./
	git commit -a -m "$COMMIT_MESSAGE"
}

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
		if [ -z $RELEASE_VERSION ]; then echo "Not found release version on commit message."; exit 127; fi
		RELEASE_DIR="${RELEASE_DIR}-$RELEASE_VERSION"
		RELEASE_COMMIT_MSG="Production: Release version $RELEASE_VERSION from $COMMIT_HASH"

		# on master
		git tag -a "v${RELEASE_VERSION}" -m "Release version $RELEASE_VERSION"

		# on release
		BRANCH_COMMIT "$RELEASE_BRANCH" "$RELEASE_COMMIT_MSG" "$RELEASE_DIR"

		git tag -a "v${RELEASE_VERSION}-release" -m "Production: Release version $RELEASE_VERSION"
		test $? -eq "0" && git push $REPO $RELEASE_BRANCH > /dev/null 2>&1 && git push --tags $REPO > /dev/null 2>&1
		git checkout $CURRENT_BRANCH
		;;
	publish) ;;
esac
