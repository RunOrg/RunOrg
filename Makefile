all: runorg
	./runorg reset

depend: 
	opam install postgresql-ocaml ssl sha batteries ocurl

toolchain:
	make -C syntax

runorg: toolchain
	make -C server
	cp server/main.byte runorg
	chmod a+x runorg

clean: 
	rm -f runorg
	make -C server clean

start:
	mkdir .bot 
	echo "#!/bin/sh\ncd ..\n./runorg bot\n" > .bot/run 
	chmod u+x .bot/run
	supervise .bot & 
	mkdir .www
	echo "#!/bin/sh\ncd ..\n./runorg www\n" > .www/run 
	chmod u+x .www/run
	supervise .www & 

stop:
	svc -d .bot || echo "bot was not running"
	rm -rf .bot
	svc -d .www || echo "web server was not running"
	rm -rf .www
