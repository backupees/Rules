#/bin/bash
cd '../../'
DIR=$(pwd)
DIR_OUT=${DIR}/docOut/inheritance
if ! [ -d "$DIR_OUT" ]; then
    mkdir -p ./docOut/surya_inheritance
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
        npx surya inheritance $i | dot -Tpng > ../docOut/surya_inheritance/surya_inheritance_$filename.png;
    fi
done;