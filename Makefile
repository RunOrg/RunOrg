all: runorg
	./runorg reset

count: clean
	./count.sh

tests: 
	make -C testc
	testc/testc.native

depend: 
	opam switch 4.00.0
	opam install postgresql ssl sha batteries ocurl menhir ocamlnet

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
	supervise .server & 

stop:
	svc -d .server || echo "server was not running"
	rm -rf .server/supervise
