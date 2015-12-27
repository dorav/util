#!/bin/bash

INPUT=$1
OUTPUT=$2

usage ()
{
	echo "This program concatecates .ts files into a single file"
	echo "It relies on having ffmpeg installed and set in PATH variable"
	echo "Usage: $0 input_folder [output_file = output.ts]"
}

if [ -z $INPUT ]; then 
	usage;
	exit;
fi

if [ -z $OUTPUT ]; then OUTPUT=output.ts; fi

for i in `ls -1 $INPUT/*.ts`; do echo "file $i" >> fileList.txt; done

ffmpeg -f concat -i fileList.txt -c copy $OUTPUT
