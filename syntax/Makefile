all: syntax.cmo

clean:
	rm -f *.cmo *.cmi

test: test.ml syntax.cmo
	ocamlfind ocamlc -verbose -syntax camlp4o -package camlp4 -ppopt "syntax.cmo" test.ml

distclean: 
	rm -f *.cmo *.cmi
	rm -f *~

syntax.cmo: syntax.ml
	ocamlc -pp 'camlp4o q_MLast.cmo pa_extend.cmo' -I +camlp4 -c syntax.ml

