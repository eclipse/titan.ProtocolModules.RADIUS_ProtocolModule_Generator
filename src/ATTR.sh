#!/bin/sh
#set -x
#/******************************************************************************
#* Copyright (c) 2000-2019 Ericsson Telecom AB
#* All rights reserved. This program and the accompanying materials
#* are made available under the terms of the Eclipse Public License v2.0
#* which accompanies this distribution, and is available at
#* https://www.eclipse.org/org/documents/epl-2.0/EPL-2.0.html
#*
#* Contributors:
#* Timea Moder
#* Endre Kulcsar
#* Gabor Szalai
#* Janos Kovesdi
#* Kulcsár Endre
#* Zoltan Medve
#* Tamas Korosi
#******************************************************************************/


# ATTR.sh [OPTION] ... RDF-FILEs
# {-v <variable-name>=<value>} {RDF-files} 

ATTRSCRIPT="ATTR.awk"
TTCN3FILE="RADIUS_Types"

if [ $# -lt 1 ]; then 
  echo "ERROR: Too few arguments"
  echo "Usage: $0 [-vNAME=VALUE] ... RDF-FILEs"
  echo "Where: -v sets variable NAME to VALUE"
  echo ""
  echo "Supported variables:"
  echo "  module_id ................ Name of generated TTCN-3 module"
  echo "  use_application_revision . Use revision prefix in ATTR identifier"
  echo "  enum_2_UnsignedInt ....... Replace enumeration ATTRs with UnsignedInteger"
  echo "  old_structured_code....... Generate original structured TTCN-3 code"
  exit 1
fi

     # check gawk version
     FIRSTLINE=`gawk --version|head -1`
     PRODUCT=`echo ${FIRSTLINE} | gawk '{ print $1 $2 }'`
     VERSION=`echo ${FIRSTLINE} | gawk '{ print $3 }'`
     if [ ${PRODUCT} != "GNUAwk" ]; then
       echo "ERROR: GNU Awk required"
       exit 1
     fi
     RESULT=`echo ${VERSION} | gawk '{ print ($0 < "3.1.6") }'`
     if [ ${RESULT} != 0 ]; then
       echo "ERROR: GNU Awk version >3.1.6 required (${VERSION} found)"
       exit 1
     fi

# Process arguments

AWKARGS=$@
while [ $# -ge 1 ]; do
  case $1 in
  -v)
      shift; 
      case $1 in
      module_id=*)
        TTCN3FILE=`echo $1 | sed 's/module_id=//'`
        if [ -f "RADIUS_EncDec.cc" ]; then 
          cmd="s/#include \"RADIUS_Types.hh\"/#include \"${TTCN3FILE}.hh\"/
               s/namespace RADIUS__Types/namespace ${TTCN3FILE}/
               s/RADIUS_EncDec/${TTCN3FILE}_RADIUS_EncDec/g"
          cat "RADIUS_EncDec.cc" \
              | sed "${cmd}" > ${TTCN3FILE}"_RADIUS_EncDec.cc"
        else
          echo "ERROR: Missing RADIUS_EncDec.cc file"
          exit 1
        fi
        ;;
      use_application_revision=*)
        ;;
      enum_2_UnsignedInt=*) 
        ;;
      old_structured_code=*) 
        ;;
      *) echo "ERROR: Unknown variable $1!"; exit 1;;
      esac
      ;;
  *) 
     # end of options
     if [ $# -lt 1 ]; then
       echo "ERROR: No input RDF file"
       exit 1
     fi
     # check gawk existence
     which gawk > /dev/null 2> /dev/null
     if [ ! $? ]; then
      echo "ERROR: GNU awk can not be found"
      exit 1
     fi
     # check input awk script
     if [ -f ${ATTRSCRIPT} ]; then
       gawk -f ${ATTRSCRIPT} ${AWKARGS} > ${TTCN3FILE}".ttcn"
     else
       echo "ERROR: ATTR.awk not found"
       exit 1
     fi
     break
     ;;
  esac
  shift
done
