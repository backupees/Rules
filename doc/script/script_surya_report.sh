#/bin/bash
cd '../../'
DIR=$(pwd)
DIR_OUT=${DIR}/docOut/surya_report
if ! [ -d "$DIR_OUT" ]; then
    mkdir -p ./docOut/surya_report
fi
cd './src'
DIR=$(pwd)
# Deliberately relative: surya records the path it was given in its output, so an absolute
# path here would bake the checkout location into the committed reports.
for i in $(find . -type f);
do
    filename=${i##*/}
    ext=${i##*.}
    if [[ $ext == 'sol' ]]; then
        npx surya mdreport ../docOut/surya_report/surya_report_$filename.md $i;
    fi
done;