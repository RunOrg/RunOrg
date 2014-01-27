all: runorg
	./runorg reset

tests: 
	make -C testc
	testc/testc.native

depend: 
	opam install postgresql-ocaml ssl sha batteries ocurl menhir

toolchain:
	make -C syntax
	make -C plang

runorg: toolchain tests
	make -C server
	make -C admin
	cp server/main.byte runorg
	chmod a+x runorg

clean: 
	rm -f runorg
	make -C server clean

start:
	mkdir .server
	echo "#!/bin/sh\ncd ..\n./runorg\n" > .server/run 
	chmod u+x .server/run
	supervise .server & 

stop:
	svc -d .server || echo "server was not running"
	rm -rf .server
