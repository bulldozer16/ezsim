ezasm: lex.yy.c y.tab.c
	gcc -g -w lex.yy.c y.tab.c -o ezsim

lex.yy.c: y.tab.c ezsim.l
	lex ezsim.l

y.tab.c: ezsim.y
	yacc -d ezsim.y

clean: 
	rm -f lex.yy.c y.tab.c y.tab.h ezsim
