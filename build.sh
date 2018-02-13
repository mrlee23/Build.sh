#!/bin/bash

if [ -z "$GH_TOKEN" ]; then "GH_TOKEN is not setted" 1>&2; fi
if [ -z "$REPO" ]; then REPO=$(sed "s/https:\/\/github.com/https:\/\/${GH_TOKEN}@github.com/g" <<< $(git config remote.origin.url)); fi
if [ -n "$GIT_USER_NAME" ]; then git config --global user.name "$GIT_USER_NAME"; fi
if [ -n "$GIT_USER_EMAIL" ]; then git config --global user.email "$GIT_USER_EMAIL"; fi

GIT_REMOTE_ORIGIN_URL=`git config remote.origin.url`
COMMIT_MSG=`git log --oneline -n 1 --pretty='%s'`
COMMIT_HASH=`git log --oneline -n 1 --pretty='%h'`

CURRENT_BRANCH=`git rev-parse --abbrev-ref HEAD`

BRANCH_COMMIT () {
	BRANCH=$1
	COMMIT_MESSAGE=$2
	TMP_DIR=$3
	WITH_PUSH=$4
	if [ -z "$BRANCH" ]; then echo "Branch does not specified."; exit 127; fi
	if [ -z "$COMMIT_MESSAGE" ]; then echo "Message does not specified."; exit 127; fi
	if [ -z "$TMP_DIR" ]; then TMP_DIR=".${BRANCH}_tmp"; fi

	echo "Copy to $TMP_DIR"
	git branch -D $BRANCH
	git checkout --orphan $BRANCH
	rm -rf ./$TMP_DIR
	rsync -avr --exclude=.git ./ ./$TMP_DIR/ # copy master to branch's tmp directory
	git pull origin $BRANCH
	
	echo "Restore from $TMP_DIR"
	rsync -avr --exclude=.git --delete ./$TMP_DIR/ ./ # mv branch's tmp directory to branch and remove anothers.
	
	echo "Commit..."
	git add ./
	git commit -a -m "$COMMIT_MESSAGE"

	if [ "$WITH_PUSH" == "TRUE" ]
	then
		test $? -eq "0" && echo "Pushing..." && git push $REPO $BRANCH
	fi
}

PAGES_COMMIT () {
	BRANCH=$1
	COMMIT_MESSAGE=$2
	TMP_DIR=$3
	WITH_PUSH=$4
	CURRENT_DIR=`pwd`
	if [ -z "$BRANCH" ]; then echo "Branch does not specified."; exit 127; fi
	if [ -z "$COMMIT_MESSAGE" ]; then echo "Message does not specified."; exit 127; fi
	if [ -z "$TMP_DIR" ]; then TMP_DIR=".${BRANCH}_tmp"; fi
	cd "$TMP_DIR"
	TMP_DIR=`pwd`
	cd "$CURRENT_DIR"

	TMP_GIT_DIR="${TMP_DIR}_git"

	[[ `git ls-remote --heads origin $BRANCH | wc -l` -gt 0 ]] && BRANCH_EXISTS=TRUE

	if [ ! -d "$TMP_GIT_DIR" ]; then mkdir -p "$TMP_GIT_DIR"; fi
	
	cd "$TMP_GIT_DIR"
	git init
	git remote add origin $GIT_REMOTE_ORIGIN_URL
	git checkout --orphan $BRANCH
	if [ $BRANCH_EXISTS == TRUE ]
	then
		git pull origin $BRANCH
	fi
	
	echo "Copy from $TMP_DIR"
	rsync -avr --exclude=.git --delete-after "$TMP_DIR/" ./ # mv branch's tmp directory to branch and remove anothers.
	
	echo "Commit..."
	git add ./
	git commit -a -m "$COMMIT_MESSAGE"

	if [ $WITH_PUSH == TRUE ]
	then
		test $? -eq "0" && echo "Pushing..." && git push $REPO $BRANCH
	fi
	cd "$CURRENT_DIR"
	rm -rf "$TMP_GIT_DIR"
}

case $1 in
	release)
		if [ -z "$RELEASE_WITH_VERSION" ]; then RELEASE_BRANCH="TRUE"; fi
		if [ -z "$RELEASE_BRANCH" ]; then RELEASE_BRANCH="release"; fi
		if [ -z "$RELEASE_DIR" ]; then RELEASE_DIR=".release"; fi
		if [ -z "$RELEASE_REGEXP" ]; then RELEASE_REGEXP="release[d]?.?v*"; fi
		if [ -z "$RELEASE_VERSION_REGEXP" ]; then RELEASE_BRANCH="[0-9]+\.[0-9]+(\.[0-9]+)?"; fi
		shopt -s nocasematch # case insensitive
		if [[ ! $COMMIT_MSG =~ $RELEASE_REGEXP ]]
		then
			echo "Passed to release this commit: $COMMIT_HASH"
			echo "\"$COMMIT_MSG\" is not matched with \"$RELEASE_REGEXP\""
			exit
		fi
		shopt -u nocasematch # case insensitive

		if [ "$RELEASE_WITH_VERSION" == "TRUE" ]
		then
			[[ $COMMIT_MSG =~ $RELEASE_VERSION_REGEXP ]] && RELEASE_VERSION="${BASH_REMATCH[0]}"
			if [ -z $RELEASE_VERSION ]; then echo "Not found release version on commit message."; exit 127; fi
			RELEASE_DIR="${RELEASE_DIR}-$RELEASE_VERSION"

			if [ -z "$RELEASE_LABEL" ]
			then
				RELEASE_COMMIT_MSG="Release version $RELEASE_VERSION from $COMMIT_HASH"
			else
				RELEASE_COMMIT_MSG="${RELEASE_LABEL}: Release version $RELEASE_VERSION from $COMMIT_HASH"
			fi

			# on master
			git tag -a "v${RELEASE_VERSION}" -m "Release version $RELEASE_VERSION"

			# on release
			BRANCH_COMMIT "$RELEASE_BRANCH" "$RELEASE_COMMIT_MSG" "$RELEASE_DIR"

			git tag -a "v${RELEASE_VERSION}-release" -m "$RELEASE_COMMIT_MSG"
		else
			if [ -z "$RELEASE_LABEL" ]; then RELEASE_LABEL="Release"; fi
			RELEASE_COMMIT_MSG="${RELEASE_LABEL}: $COMMIT_MSG from $COMMIT_HASH"

			BRANCH_COMMIT "$RELEASE_BRANCH" "$RELEASE_COMMIT_MSG" "$RELEASE_DIR" "TRUE"
		fi
		test $? -eq "0" && git push $REPO $RELEASE_BRANCH > /dev/null 2>&1 && git push --tags $REPO > /dev/null 2>&1
		git checkout $CURRENT_BRANCH
		;;
	publish)
		if [ -z "$PUBLISH_LABEL" ]; then PUBLISH_LABEL="Publish"; fi
		if [ -z "$PUBLISH_BRANCH" ]; then PUBLISH_BRANCH="publish"; fi
		if [ -z "$PUBLISH_DIR" ]; then PUBLISH_DIR=".publish"; fi
		if [ -z "$PUBLISH_COMMIT_MSG"]; then PUBLISH_COMMIT_MSG="${PUBLISH_LABEL}: $COMMIT_MSG from $COMMIT_HASH"; fi
		PAGES_COMMIT "$PUBLISH_BRANCH" "$PUBLISH_COMMIT_MSG" "$PUBLISH_DIR" "TRUE"
		git checkout $CURRENT_BRANCH
		;;
	gh-pages)
		if [ -z "$GH_PAGES_LABEL" ]; then GH_PAGES_LABEL="Pages"; fi
		if [ -z "$GH_PAGES_BRANCH" ]; then GH_PAGES_BRANCH="gh-pages"; fi
		if [ -z "$GH_PAGES_DIR" ]; then GH_PAGES_DIR=".gh-pages"; fi
		if [ -z "$GH_PAGES_COMMIT_MSG"]; then GH_PAGES_COMMIT_MSG="${GH_PAGES_LABEL}: $COMMIT_MSG from $COMMIT_HASH"; fi
		PAGES_COMMIT "$GH_PAGES_BRANCH" "$GH_PAGES_COMMIT_MSG" "$GH_PAGES_DIR" "TRUE"
		git checkout $CURRENT_BRANCH
		;;
esac
