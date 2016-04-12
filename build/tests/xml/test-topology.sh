#!/bin/sh
#-*-sh-*-

#
# Copyright © 2009 CNRS
# Copyright © 2009-2015 Inria.  All rights reserved.
# Copyright © 2009-2012 Université Bordeaux
# Copyright © 2010 Cisco Systems, Inc.  All rights reserved.
# See COPYING in top-level directory.
#

# Check the conformance of `lstopo' for all the XML
# hierarchies available here.  Return true on success.

HWLOC_top_builddir="/root/enpower/pocl/hwloc/hwloc-1.11.2/build"
HWLOC_top_srcdir="/root/enpower/pocl/hwloc/hwloc-1.11.2"
lstopo="/root/enpower/pocl/hwloc/hwloc-1.11.2/build/utils/lstopo/lstopo-no-graphics"

HWLOC_PLUGINS_PATH=${HWLOC_top_builddir}/src
export HWLOC_PLUGINS_PATH

if test x0 = x1; then
  # make sure we use default numeric formats
  LANG=C
  LC_ALL=C
  export LANG LC_ALL
fi

error()
{
    echo $@ 2>&1
}

if [ ! -x "$lstopo" ]
then
    error "Could not find executable file \`$lstopo'."
    exit 1
fi


: ${TMPDIR=/tmp}
{
  tmp=`
    (umask 077 && mktemp -d "$TMPDIR/fooXXXXXX") 2>/dev/null
  ` &&
  test -n "$tmp" && test -d "$tmp"
} || {
  tmp=$TMPDIR/foo$$-$RANDOM
  (umask 077 && mkdir "$tmp")
} || exit $?
file="$tmp/lstopo_xml.output"

set -e

output="$1"
dirname=`dirname $1`
filename=`basename $1`
basename=`basename $1 .xml`
basename=`basename $basename .output`

source="${dirname}/${basename}.xml"
source_file="${dirname}/${basename}.source"

if test \! -f "$source" && test \! -f "$source_file"; then
  echo "Missing both ${basename}.xml and ${basename}.source"
  exit 1
fi
test -f "$source_file" && source="${dirname}/"`cat $source_file`

options_file="${dirname}/${basename}.options"
test -f "$options_file" && opts=`cat $options_file`

test -f "${dirname}/${basename}.env" && . "${dirname}/${basename}.env"

do_run()
{
  echo $lstopo --if xml --input "$source" --of xml "$file" $opts
  $lstopo --if xml --input "$source" --of xml "$file" $opts

  if [ "$HWLOC_UPDATE_TEST_TOPOLOGY_OUTPUT" != 1 ]
  then
    diff -u -w "$output" "$file"
  else
    if ! diff "$output" "$file" >/dev/null
    then
	cp -f "$file" "$output"
	echo "Updated $filename"
    fi
  fi

  if [ -n "" ]
  then
    cp -f "$HWLOC_top_srcdir"/src/hwloc.dtd "$tmp/"
    ( cd $tmp ;  --valid $file ) > /dev/null
  fi

  rm "$file"
}

do_run_with_output()
{
  echo $lstopo --if xml --input "$source" "$file" $opts
  $lstopo --if xml --input "$source" "$file" $opts

  if [ "$HWLOC_UPDATE_TEST_TOPOLOGY_OUTPUT" != 1 ]
  then
    diff -u -w "$output" "$file"
  else
    if ! diff "$output" "$file" >/dev/null
    then
        cp -f "$file" "$output"
        echo "Updated ${basename}.xml"
    fi
  fi

  rm $file
}

export HWLOC_NO_LIBXML_IMPORT
export HWLOC_NO_LIBXML_EXPORT

if test "$filename" = "${basename}.xml"; then
  echo "Importing with default parser and reexporting with minimalistic implementation..."
  HWLOC_NO_LIBXML_IMPORT=0
  HWLOC_NO_LIBXML_EXPORT=1
  do_run "$dirname" "$basename"
  echo "Importing with minimalistic parser and reexporting with default implementation..."
  HWLOC_NO_LIBXML_IMPORT=1
  HWLOC_NO_LIBXML_EXPORT=0
  do_run "$dirname" "$basename"
else if test "$filename" = "${basename}.output"; then
  echo "Importing with default parser"
  HWLOC_NO_LIBXML_IMPORT=0
  do_run_with_output "$dirname" "$basename"
  echo "Importing with minimalistic parser"
  HWLOC_NO_LIBXML_IMPORT=1
  do_run_with_output "$dirname" "$basename"
else
  echo "Filename must end with either .xml or .output"
  exit 1
fi fi

rm -rf "$tmp"