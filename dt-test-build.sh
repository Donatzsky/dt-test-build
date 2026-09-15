#!/bin/bash

# MIT License
# Copyright (c) 2026 Nis Donatzsky Hansen

usage="Usage: dt-test-build.sh [-d <path> [-m | -b <branch> | -p <#>] [-r <remote|URL>] [-s] [-l <label>]] [-i | -u <name>]

-d <path>
   Directory with darktable Git checkout
-m
   Build master
-b <branch name>
   Build branch
-p <1234>
   Build pull request
-r <remote|repo URL>
   Remote or repository URL to fetch branch from
-s
   Update submodules
-l <label>
   Label for the build
-i
   List installed builds
-u <directory name>
   Uninstall build
-h
   Show this help"

######################################################
## Configuration

# Modify as needed. No trailing /
base_install_dir="$HOME/.local/bin"
base_config_dir="$XDG_CONFIG_HOME"

# Maybe modify, but careful
source_dir=""
branch_remote=""

# Should normally not be modified
pr_remote="https://github.com/darktable-org/darktable"
tags_remote="https://github.com/darktable-org/darktable"
temp_dir="/tmp"

######################################################

## Flags

master=0
branch=""
pr=0
submodules=0
label=""
installed=0
uninstall=""
help=0
bad_flag=0

while getopts d:mb:p:r:sl:iu:h flag
do
	case "${flag}" in
		d) source_dir="${OPTARG}";;
		m) master=1;;
		b) branch="${OPTARG}";;
		p) pr="${OPTARG}";;
		r) branch_remote="${OPTARG}";;
		s) submodules=1;;
		l) label="${OPTARG}";;
		i) installed=1;;
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

if [ $master = 0 ] && [ "$branch" = "" ] && [ $pr = 0 ] && [ $installed = 0 ] && [ "$uninstall" = "" ]; then
	echo "One of -m, -b, -p, -i or -u must be specified"
	exit 1
fi

## List installed

if [ $installed = 1 ]; then
	echo "Installed builds:"
	echo
	cd "$base_install_dir"
	ls -d darktable-test-*
	exit
fi

## Uninstall

if [ "$uninstall" != "" ]; then
	echo "Uninstalling: ${uninstall}"
	echo

	read -p "Remove application? (y/N) " -n 1 -r
	echo
	if [[ $REPLY =~ ^[Yy]$ ]]; then
		rm -r "${base_install_dir}/${uninstall}"
		xdg-desktop-menu uninstall "${uninstall}.desktop"
	fi

	read -p "Remove config? (y/N) " -n 1 -r
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

# Building master
if [ $master = 1 ]; then
	version=$(./tools/get_git_version_string.sh)
	tag="$version"
fi

# Building branch
if [ "$branch" != "" ]; then
	if [ "$branch_remote" = "" ]; then
		echo "Remote (-r) required to fetch branch"
		exit 1
	fi
	git fetch "$branch_remote" "$branch" || exit 1
	git checkout FETCH_HEAD

	version=$(./tools/get_git_version_string.sh)
	tag="${version}_${branch}"
fi

# Building PR
if [ $pr -gt 0 ]; then
	git fetch "$pr_remote" pull/$pr/head || exit 1
	git checkout FETCH_HEAD

	version="$(./tools/get_git_version_string.sh)"
	tag="${version}_pr${pr}"
fi

if [ "$label" = "" ]; then
	description="${tag}"
	tag_label="${tag}"
else
	description="${tag} / ${label}"
	tag_label="${tag}_${label}"
fi
description_esc="${description//\//\\/}" # Don't confuse sed
tag_label_safe="${tag_label//[\$\`\"\'\\~\/ ]/_}"

install_dir="${base_install_dir}/darktable-test-${tag_label_safe}"
config_dir="${base_config_dir}/darktable-test-${tag_label_safe}"
config_dir_esc="${config_dir//\//\\/}"

## Build and install

rm -r build
rm -r "$install_dir"

if ! ./build.sh --prefix "$install_dir" --build-type Release --install; then
	git switch -q master
	echo
	echo "Something went wrong"
	exit 1
fi

git switch -q master

sed "s/^Name=.*/Name=Darktable (${description_esc})/" "${install_dir}/share/applications/org.darktable.darktable.desktop" |
	sed "s/%U/--configdir \"${config_dir_esc}\" %U/" > "${temp_dir}/darktable-test-${tag_label_safe}.desktop"

xdg-desktop-menu install "${temp_dir}/darktable-test-${tag_label_safe}.desktop"

mkdir "$config_dir"

echo
echo "Installed to: ${install_dir}"
echo "Config: ${config_dir}"
