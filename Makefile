count: clean
	./count.sh

all: runorg
	./runorg reset

tests: 
	make -C testc
	testc/testc.native

depend: 
	opam switch 4.00.0
	opam install postgresql-ocaml ssl sha batteries ocurl menhir

toolchain:
	make -C syntax
	make -C plang

runorg: toolchain tests
	make -C server
	make -C sites/admin
	make -C sites/docs
	make -C sites/default
	cp server/main.byte runorg
	chmod a+x runorg

clean: 
	find . -name '*~' | xargs rm -f 
	rm -f runorg
	rm -rf sites/*/.assets
	make -C syntax clean 
	make -C server clean
	make -C testc clean
	make -C plang clean

start:
	mkdir .server
	echo "#!/bin/sh\ncd ..\n./runorg\n" > .server/run 
	chmod u+x .server/run
	supervise .server & 

stop:
	svc -d .server || echo "server was not running"
	rm -rf .server
