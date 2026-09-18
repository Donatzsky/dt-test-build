#!/bin/bash

# MIT License
# Copyright (c) 2026 Nis Donatzsky Hansen

usage="Usage: dt-test-build.sh [-s <path> [-m | -p <#> | [-b <branch> -r <remote|URL>]] [-S] [-a <args>] [-l <label>] [-c <name>] [-d <config>] [-x]] [-i | -u <name>]

-s <path>
   Directory with darktable source Git checkout
-m
   Build master
-p <1234>
   Build pull request
-b <branch name>
   Build branch
-r <remote|repo URL>
   Remote or repository URL to fetch branch from
-S
   Update submodules
-a <build arguments>
   Pass arguments directly to build.sh
-l <label>
   Label for the build
-c <directory name>
   Override config directory name
-d <config directory name>
   Duplicate (copy) existing config
-x
   Dry-run. Don't build or install
-i
   List installed builds
-u <directory name>
   Uninstall build
-h
   Show this help"

######################################################
## Configuration

# Modify as needed
base_install_dir="$HOME/.local/bin"
base_config_dir="$XDG_CONFIG_HOME"
build_args="" # Concatenated with -a

# Maybe modify, but careful. Arguments take precedence
source_dir=""
config_copy_dir=""
config_dir_name="" # Disables automatic unique config directories
branch_remote=""

# Should normally not be modified
pr_remote="https://github.com/darktable-org/darktable"
tags_remote="https://github.com/darktable-org/darktable"

######################################################

## Flags

# source_dir in config
master=0
branch=""
pr=0
# branch_remote in config
submodules=0
# build_args in config
label=""
# config_dir_name in config
# config_copy_dir in config
dryrun=0
installed=0
uninstall=""
help=0
bad_flag=0

build_flags=0
manage_flags=0

while getopts s:mb:p:r:Sa:l:c:d:xiu:h flag
do
	case "$flag" in
		s) source_dir="$OPTARG";;
		m) master=1
		   ((build_flags++));;
		b) branch="$OPTARG"
		   ((build_flags++));;
		p) pr="$OPTARG"
		   ((build_flags++));;
		r) branch_remote="$OPTARG";;
		S) submodules=1;;
		a) build_args="$build_args $OPTARG";;
		l) label="$OPTARG";;
		c) config_dir_name="$OPTARG";;
		d) config_copy_dir="$OPTARG";;
		x) dryrun="$OPTARG";;
		i) installed=1
		   ((manage_flags++));;
		u) uninstall="$OPTARG"
		   ((manage_flags++));;
		h) help=1;;
		*) bad_flag=1;;
	esac
done

if [ ! "$#" -gt 0 ] || [ $help = 1 ] || [ $bad_flag = 1 ]; then
	echo "$usage"
	exit
fi

## Validate input

if [ $build_flags = 0 ] && [ $manage_flags = 0 ]; then
	echo "One of -m, -b, -p, -i or -u must be specified"
	exit 1
fi

if [ $build_flags -gt 0 ] && [ $manage_flags -gt 0 ]; then
	echo "Incompatible arguments"
	exit 1
fi

if [ $build_flags -gt 1 ] || [ $manage_flags -gt 1 ]; then
	echo "Too many arguments of same type"
	exit 1
fi

if [ $build_flags = 1 ] && [ "$source_dir" = "" ]; then
	echo "Darktable source directory (-s) not specified"
	exit 1
fi

if [ "$branch" != "" ] && [ "$branch_remote" = "" ]; then
	echo "Remote (-r) required to fetch branch"
	exit 1
fi

if [[ "$config_dir_name" =~ "/" ]]; then
	echo "Illegal character '/' in config_dir_name (-c)"
	exit 1
fi

if [[ "$config_copy_dir" =~ "/" ]]; then
	echo "Illegal character '/' in config_copy_dir (-d)"
	exit 1
fi

if [ "$config_copy_dir" != "" ] && [ ! -d "$base_config_dir/$config_copy_dir" ]; then
	echo "config_copy_dir (-d) not found"
	exit 1
fi

## List installed

if [ $installed = 1 ]; then
	echo "Installed builds:"
	echo
	cd "$base_install_dir" || exit
	ls -d darktable-test-*
	exit
fi

## Uninstall

if [ "$uninstall" != "" ]; then
	echo "Uninstalling: ${uninstall}"
	echo

	read -p "Remove build? (y/N) " -n 1 -r
	echo
	if [[ $REPLY =~ ^[Yy]$ ]]; then
		rm -r "${base_install_dir:?}/${uninstall}"
		xdg-desktop-menu uninstall "${uninstall}.desktop"
	fi

	read -p "Remove config? (y/N) " -n 1 -r
	echo
	if [[ $REPLY =~ ^[Yy]$ ]]; then
		rm -r "${base_config_dir:?}/${uninstall}"
	fi

	exit
fi

## Prepare

cd "$source_dir" || exit 1

if [ ! -f build.sh ]; then
	echo "build.sh not found"
	exit 1
fi

git switch -q master
echo "Pulling master..."
git pull || exit 1
if [ $submodules = 1 ]; then
	echo "Updating submodules..."
	git submodule update
fi
git fetch "$tags_remote" --tags

# Building master
if [ $master = 1 ]; then
	version=$(./tools/get_git_version_string.sh)
	tag=""
fi

# Building branch
if [ "$branch" != "" ]; then
	git fetch "$branch_remote" "$branch" || exit 1
	git checkout FETCH_HEAD

	version=$(./tools/get_git_version_string.sh)
	tag="${branch}"
fi

# Building PR
if [ "$pr" -gt 0 ]; then
	git fetch "$pr_remote" pull/"$pr"/head || exit 1
	git checkout FETCH_HEAD

	version="$(./tools/get_git_version_string.sh)"
	tag="pr${pr}"
fi

## Description

if [ "$tag" = "" ]; then
	description="${version}"
	dir_desc="${version}"
else
	description="${version} / ${tag}"
	dir_desc="${version}_${tag}"
fi

if [ "$label" != "" ]; then
	description="${description} / ${label}"
	dir_desc="${dir_desc}_${label}"
fi

description_esc="${description//\//\\/}" # Don't confuse sed
dir_desc_safe="${dir_desc//[\$\`\"\'\\~\/ ]/_}" # Not taking any chances

install_dir="${base_install_dir}/darktable-test-${dir_desc_safe}"

if [ "$config_dir_name" = "" ]; then
	config_dir_name="darktable-test-${dir_desc_safe}"
	config_dir="${base_config_dir}/${config_dir_name}"
else
	config_dir="${base_config_dir}/${config_dir_name}"
fi
config_dir_esc="${config_dir//\//\\/}"

## Build and install

if [ "$dryrun" = 0 ]; then
	rm -r build
	rm -r "$install_dir"

	if ! ./build.sh --prefix "$install_dir" --build-type Release --install $build_args; then
		git switch -q master
		exit 1
	fi

	cd "${install_dir}/share/applications/" || exit 1

	sed "s/^Name=.*/Name=Darktable (${description_esc})/" "org.darktable.darktable.desktop" |
		sed "s/%U/--configdir \"${config_dir_esc}\" %U/" > "darktable-test-${dir_desc_safe}.desktop"

	xdg-desktop-menu install "darktable-test-${dir_desc_safe}.desktop"

	cd - > /dev/null

	mkdir -p "$config_dir"

	if [ "$config_copy_dir" != "" ]; then
		echo
		echo "Copying config from '${config_copy_dir}' to '${config_dir_name}'..."
		cd "$base_config_dir" || exit 1
		cp -i -a "$config_copy_dir/." "$config_dir_name/"
		cd - > /dev/null
	fi
fi

git switch -q master

echo
echo "Installed to: ${install_dir}"
echo "Config: ${config_dir}"
