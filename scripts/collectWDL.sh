#! /usr/bin/env bash

#--------------------------------------
# collectWDL.sh <filename>
#
# extract import statement WDLs, docker info; download subWDL files
#   assumuptions: <filename> in current working directory
#                 saving retreived files to current working directory
#
#--------------------------------------

#set -o errexit
set -o pipefail
set -o nounset

usage() { echo "$0 filename"
          echo "    -h help"
          exit 0; 
        } 

while getopts ":hrd:" opt; do
  case $opt in
    d)
      depth=$OPTARG >&2 # depth variable used for recursion tracking
      ;;
    h)
      usage
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      usage
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done
shift $((OPTIND -1))

WDLFILE=$1
VALUE=${depth:-}

# if no recursion depth index given, default = 0
if [[ -z ${VALUE} ]]
  then  
    depth=0
fi

# check for valid input file
if [[ ! -f $WDLFILE ]] 
  then
    echo "error: missing input file"
    usage
    exit 1
fi

if [[ ! -f $WDLFILE ]] 
  then
    echo "input file, $WDLFILE, not found."
    exit 1
fi

if [[ ! -s $WDLFILE ]] 
  then
    echo "input file $WDLFILE is empty"
    exit 1
else

# set up names of working files for the current recursion depth
index=$((depth+1))
importsfile="${WDLFILE}.imports.${index}.txt"
importsresult="imports.${index}.txt"

# check if subWDLs were found in the current WDL file
  grep import $WDLFILE | cut -d '"' -f 2 | grep http > $importsfile
  grep "docker:" $WDLFILE >> docker.txt
  echo "evaluated $WDLFILE for imports and docker images"
  # increment recursion depth index
  ((depth++))
  if [[ ! -s $importsfile ]] 
    then
      echo "    no imports in $importsfile"
      rm $importsfile
      sort -u docker.txt > tmp
      mv tmp docker.txt
      exit 0
    else
      if [[ ! -d $depth ]]
        then
          mkdir $depth
      fi
  fi
fi

# extract subWDL name from URL; download subWDL into subdirectory
# rename "descriptor" file with appropriate subWDL name
for i in $(cat $importsfile)
  do
    wdlname=$(echo $i | awk -v OFS='__' '{split($0, a, "/"); print a[7],a[9]}' | sed 's/:/__/g')
    wget -q $i
    echo "  retrieved $i"
    mv descriptor $depth/${wdlname}.wdl
    echo "$depth/${wdlname}.wdl" >> $importsresult
done

# clean up; uniqueify docker info
rm $importsfile

sort -u docker.txt > tmp
mv tmp docker.txt

# for each subWDL, look for subWDLs 
for i in $(cat $importsresult)
  do 
    ./collectWDL.sh -d $depth $i 
done