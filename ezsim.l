/* 
 * File:   ezsim.l
 * Author: Sergio Vargas
 *
 * Created on 10 de marzo de 2016, 01:20
 */

%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "y.tab.h"  	/*Se incluye el archivo donde se definen los valores de las constantes 
			correspondientes a cada palabra clave.*/
%}

cond ("EQ"|"NE"|"HS"|"LO"|"MI"|"PL"|"VS"|"VC"|"HI"|"LS"|"GE"|"LT"|"GT"|"LE"|"AL"|"eq"|"ne"|"hs"|"lo"|"mi"|"pl"|"vs"|"vc"|"hi"|"ls"|"ge"|"lt"|"gt"|"le"|"al")
set	("S"|"s")
sufijo	({cond}|{set}|{set}{cond})
registro ("R0"|"R1"|"R2"|"R3"|"R4"|"R5"|"R6"|"R7"|"R8"|"R9"|"R10"|"R11"|"R12"|"R13"|"R14"|"R15"|"r0"|"r1"|"r2"|"r3"|"r4"|"r5"|"r6"|"r7"|"r8"|"r9"|"r10"|"r11"|"r12"|"r13"|"r14"|"r15")
num	({numd}|{numh})
numd	([0-9])+
numh	"0x"([0-9A-F])+
%%
				/*Se definen todas las palabras clave del lenguaje y su valor de retorno (definido en
				constantes con el mismo nombre, que se declaran en y.tab.h;*/

("AND"|"and"){sufijo}? 			{yyless(3); return INSTR_AND;}
("EOR"|"eor"){sufijo}?			{yyless(3); return INSTR_EOR;}
("SUB"|"sub"){sufijo}?			{yyless(3); return INSTR_SUB;}
("RSB"|"rsb"){sufijo}?			{yyless(3); return INSTR_RSB;}
("ADD"|"add"){sufijo}?			{yyless(3); return INSTR_ADD;}
("ADC"|"adc"){sufijo}?			{yyless(3); return INSTR_ADC;}
("SBC"|"sbc"){sufijo}?			{yyless(3); return INSTR_SBC;}
("RSC"|"rsc"){sufijo}?			{yyless(3); return INSTR_RSC;}
("CMP"|"cmp"){sufijo}?			{yyless(3); return INSTR_CMP;}
("CMN"|"cmn"){sufijo}?			{yyless(3); return INSTR_CMN;}
("ORR"|"orr"){sufijo}?			{yyless(3); return INSTR_ORR;}
("MOV"|"mov"){sufijo}?			{yyless(3); return INSTR_MOV;}
("LSL"|"lsl"){sufijo}?			{yyless(3); return INSTR_LSL;}
("ASR"|"asr"){sufijo}?			{yyless(3); return INSTR_ASR;}
("RRX"|"rrx"){sufijo}?			{yyless(3); return INSTR_RRX;}
("ROR"|"ror"){sufijo}?			{yyless(3); return INSTR_ROR;}
("BIC"|"bic"){sufijo}?			{yyless(3); return INSTR_BIC;}
("MVN"|"mvn"){sufijo}?			{yyless(3); return INSTR_MVN;}
("MUL"|"mul"){sufijo}?			{yyless(3); return INSTR_MUL;}
("MLA"|"mla"){sufijo}?			{yyless(3); return INSTR_MLA;}
("STR"|"str"){sufijo}?			{yyless(3); return INSTR_STR;}
("LDR"|"ldr"){sufijo}?			{yyless(3); return INSTR_LDR;}
("STRB"|"strb"){sufijo}?		{yyless(4); return INSTR_STRB;}
("LDRB"|"ldrb"){sufijo}?		{yyless(4); return INSTR_LDRB;}
("B"|"b"){sufijo}?			{yyless(1); return INSTR_B;}
("LSR"|"lsr")				{return INSTR_LSR;}


{cond}					{yylval.string = (char *) strdup(yytext); return COND;}
{set}					{return SET;}
{set}{cond}				{yyless(1); return SET;}
{registro}				{yylval.string = (char *) strdup(yytext); return REGISTER;}


				/*Definición de las expresiones regulares que describen los tokens válidos.*/

[ \t]					/*No hacer nada si se encuentra un espacio o una tabulación.*/
[\n]					{return NEWLINE;}		
					/*Si se encuentra un cambio de línea, aumentar el número de línea y retornar 
					el valor constante NEWLINE (ver y.tab.h).*/
([A-Za-z]|_)([A-Za-z0-9]){0,31}		{ yylval.string = (char *) strdup(yytext); return ID;} 
					/*Cuando se encuentra un ID, se pasa el valor real del identificador a una de las variables 
					de yacc y se retorna el valor constante ID (ver y.tab.h).*/
{numd}					{ yylval.ival = atoi(yytext);return NUM;}
					/*Cuando se encuentra un NUM, se pasa el valor real del  identificador a una 
					de las variables de yacc y se retorna el valor constante NUM (ver y.tab.h).*/
{numh}					{ yylval.ival = (int)strtol(yytext, NULL, 0); return NUMH;}
					/*Cuando se encuentra un NUMH, se pasa el valor real del  identificador a una 
					de las variables de yacc y se retorna el valor constante NUMH (ver y.tab.h).*/
#{num}					{yyless(1); return PRE;}
					/*Cuando se encuentra un PRE, se pasa el valor real del  identificador a una 
					de las variables de yacc y se retorna el valor constante PRE (ver y.tab.h).*/
.					{ return *yytext;}		
					/*Si se encuentra algo que no coincida con las categorías anteriores, retornarlo.*/

%%
/*Es necesario definir esta función, pues se hace una llamada a yywrap cuando yylex()
alcanza el final del archivo.*/
int yywrap(){
	//printf("yywrap\n");
	return 1;
}

