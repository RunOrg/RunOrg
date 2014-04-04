#!/bin/sh

find . -name '*.ml'  > .allmlfiles
find . -name '*.mli' >> .allmlfiles

find sites -name '*.js'  > .alljsfiles
find plang -name '*.js' >> .alljsfiles

find . -name '*.css'  > .allcssfiles

find test -name '*.md' | xargs cat > .alldoc
find test -name '*.js' | xargs cat | sed -e '/^\/\//p; /.*/d' >> .alldoc

echo "== OCaml: " `cat .allmlfiles | xargs cat | wc -l` "lines"
echo "== JS   : " `cat .alljsfiles | xargs cat | wc -l` "lines"
echo "== CSS  : " `cat .allcssfiles | xargs cat | wc -l` "lines"
echo "== Docs : " `cat .alldoc | wc -w` "words"

rm .allmlfiles 
rm .alljsfiles 
rm .allcssfiles 
rm .alldoc 
