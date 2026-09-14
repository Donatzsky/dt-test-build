#!/bin/bash

# MIT License
# Copyright (c) 2026 Nis Donatzsky Hansen

usage="Usage: dt-test-build.sh [-d <path> [-m | -b <branch> | -p <#>] [-r <remote|URL>] [-s]] [-l] [-u <name>]

-d <path>
   Directory with darktable Git checkout
-m
   Build master
-b <branch name>
   Build branch
-p <#>
   Build pull request
-r <remote|repo URL>
   Remote or repository URL to fetch branch from
-s
   Update submodules
-l
   List installed builds
-u <directory name>
   Uninstall build"

######################################################
## Configuration

# Modify as needed. No trailing /
base_install_dir="$HOME/.local/bin"
base_config_dir="$XDG_CONFIG_HOME"

# Should normally not be modified
pr_remote="https://github.com/darktable-org/darktable"
tags_remote="https://github.com/darktable-org/darktable"
branch_remote=""
source_dir=""
temp_dir="/tmp"

######################################################

## Flags

master=0
branch=""
pr=0
submodules=0
list=0
uninstall=""
help=0
bad_flag=0

while getopts d:mb:p:r:slu:h flag
do
	case "${flag}" in
		d) source_dir="${OPTARG}";;
		m) master=1;;
		b) branch="${OPTARG}";;
		p) pr=$OPTARG;;
		r) branch_remote="${OPTARG}";;
		s) submodules=1;;
		l) list=1;;
		u) uninstall="${OPTARG}";;
		h) help=1;;
		*) bad_flag=1;;
	esac
done

if [ $bad_flag = 1 ]; then
	exit 1
fi

if [ ! "$#" -gt 0 ] || [ $help = 1 ]; then
	echo "$usage"
	exit
fi

if [ $master = 0 ] && [ "$branch" = "" ] && [ $pr = 0 ] && [ $list = 0 ] && [ "$uninstall" = "" ]; then
	echo "One of -m, -b, -p, -l or -u must be specified"
	exit 1
fi

## List builds

if [ $list = 1 ]; then
	echo "Installed test builds:"
	echo
	cd "$base_install_dir"
	ls -d darktable-test-*
	exit
fi

## Uninstall

if [ "$uninstall" != "" ]; then
	echo "Uninstalling: ${uninstall}"
	echo

	read -p "Remove application? (y/n) " -n 1 -r
	echo
	if [[ $REPLY =~ ^[Yy]$ ]]; then
		rm -r "${base_install_dir}/${uninstall}"
		xdg-desktop-menu uninstall "${uninstall}.desktop"
	fi

	read -p "Remove config? (y/n) " -n 1 -r
	echo
	if [[ $REPLY =~ ^[Yy]$ ]]; then
		rm -r "${base_config_dir}/${uninstall}"
	fi

	exit
fi

## Prepare

if [ "$source_dir" = "" ]; then
	echo "Darktable source directory (-d) not specified"
	exit 1
fi

cd "$source_dir" || exit 1

if [ ! -f build.sh ]; then
	echo "build.sh not found"
	exit 1
fi

git switch -q master
echo "Pulling master..."
git pull
if [ $submodules = 1 ]; then
	echo "Updating submodules..."
	git submodule update
fi
git fetch "$tags_remote" --tags

if [ $master = 1 ]; then
	version=$(./tools/get_git_version_string.sh)
	# commit="$(git log --format=%s -n 1 HEAD | cat)"
	commit=""
	tag="$version"
fi

if [ "$branch" != "" ]; then
	if [ "$branch_remote" = "" ]; then
		echo "Remote (-r) required to fetch branch"
		exit 1
	fi
	git fetch "$branch_remote" "$branch" || exit 1
	git checkout FETCH_HEAD

	version=$(./tools/get_git_version_string.sh)
	# commit="$(git log --format=%s -n 1 HEAD | cat)"
	commit=""
	tag="${version}_${branch}"
fi


if [ $pr -gt 0 ]; then
	git fetch "$pr_remote" pull/$pr/head || exit 1
	git checkout FETCH_HEAD

	version="$(./tools/get_git_version_string.sh)"
	commit="$(git log --format=%s -n 1 HEAD | cat)"
	tag="${version}_pr${pr}"
fi

tag_safe="${tag//[\\~\/ ]/_}"

install_dir="${base_install_dir}/darktable-test-${tag_safe}"
config_dir="${base_config_dir}/darktable-test-${tag_safe}"
config_dir_esc="${config_dir//\//\\/}"

if [ "$commit" = "" ]; then
	label="${tag}"
else
	commit_trunc="${commit:0:50}"
	commit_esc="${commit_trunc//\//\\/}"
	label="${tag} \/\/ ${commit_esc}"
fi

## Build and install

rm -r build
rm -r "$install_dir"

if ! ./build.sh --prefix "$install_dir" --build-type Release --install; then
	git switch -q master
	echo "Something went wrong"
	exit 1
fi

git switch -q master

sed "s/^Name=.*/Name=Darktable ($label)/" "${install_dir}/share/applications/org.darktable.darktable.desktop" |
	sed "s/%U/--configdir \"$config_dir_esc\" %U/" > "${temp_dir}/darktable-test-${tag_safe}.desktop"

xdg-desktop-menu install "${temp_dir}/darktable-test-${tag_safe}.desktop"

mkdir "${config_dir}"

echo "Installed to: ${install_dir}"
echo "Config: ${config_dir}"
