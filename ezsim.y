/* 
 * File:   ezsim.y
 * Author: Sergio Vargas / Héctor Porras
 *
 * Created on 25 de marzo de 2016, 11:10
 */

%{
/*Se incluyen las cabeceras necesarias*/

#include "ezsim.h"
#include "instrucciones.c"

/*Declaración de constantes*/
#define SYMB 100	//Máximo número de símbolos en la tabla.
#define BRANCH 200	//Máximo número de instrucciones branch.

/*Variables de soporte (lex-yacc)*/

extern int yylex();
extern int yyparse();
extern FILE *yyin;
typedef struct yy_buffer_state * YY_BUFFER_STATE;
extern YY_BUFFER_STATE yy_scan_string(char * str);
extern void yy_delete_buffer(YY_BUFFER_STATE buffer);
extern void yy_switch_to_buffer(YY_BUFFER_STATE new_buffer);

/*Punteros de archivos*/

FILE *asm_output; 	//Puntero al archivo de salida en ensamblador.
FILE *inputf;		//Puntero al archivo con el programa fuente.
FILE *err_file;		//Puntero al archivo de manejo de errores.

/*Variables de control*/

int linenumber = 1;	/*Se declara una variable par llevar control del número de línea.
			Se inicializa con valor de 1, pues no puede existir línea 0.*/
int err_bool = 0;	// Indica si ya apareció algún error
int inst = 0x0;		// Representación númerica de instrucción actual
int branch_count = 0;	// Conteo de instrucciones branch
char* br_str;		// Cadena de caracteres para colocación de branch
int branch_ctrl = 0;
int branch_cond = 0;
int first_pass = 1;

int cond_code = 14;	// Código de la condición, por defecto está en 14.
int reg_num = 0;

/* Registros Rd, Rn, Rm y RS utilizados en las distintas instrucciones */
int rd = 0;		
int rn = 0;
int rm = 0;
int rs = 0;

int src2 = 0;		// Valor del inmediato en las instrucciones.
int set = 0;		// Bit que indica si la instrucción debe realizar el set de las banderas.

int dir_mode = 0;	// Modo de direccionamiento para las instrucciones de memoria.

int inst_count = 0;	// Cuenta las instrucciones ejecutadas.

/*Estructura que se emplea para la tabla de símbolos.
Contiene el nombre de la entrada, el número de línea,
si es utilizada, si es parámetro o cuál es el parámetro
y en qué función se encuentra.*/

struct std_sym{ 		
	char *nombre;	 
	int dir;	
};

/*Se crea la tabla de símbolos. En este caso se implementa mediante un 
 arreglo de estructuras del tipo std_sym definido arriba, de tamaño SYMB.*/

struct std_sym symtable[SYMB];	

/*Estructura para almacenar información importante sobre un branch.
  Se vuelve necesario dado que no se van a conocer todas las etiquetas hasta 
  haber analizado por completo el archivo fuente.*/
 
struct branches{ 		
	char* label;	 
	int dir;
	int code;	
};

/*Arreglo que contiene todas las instrucciones branch en el código fuente*/

struct branches branch_table[BRANCH];

%}

/*Definición de los tipos que puede adquirir cada uno de los elementos 
  terminales y no terminales*/

%union {int ival; char *string;};

/*Definición del símbolo inicial y de los tokens de la gramática*/

%start program

%token NEWLINE
%token NUM
%token NUMH
%token ID
%token PRE

%token COND
%token SET
%token REGISTER

%token INSTR_AND
%token INSTR_EOR
%token INSTR_SUB
%token INSTR_RSB
%token INSTR_ADD
%token INSTR_ADC
%token INSTR_SBC
%token INSTR_RSC
%token INSTR_CMP
%token INSTR_CMN
%token INSTR_ORR
%token INSTR_MOV
%token INSTR_LSL
%token INSTR_ASR
%token INSTR_RRX
%token INSTR_ROR
%token INSTR_BIC
%token INSTR_MVN 
%token INSTR_MUL
%token INSTR_MLA
%token INSTR_STR
%token INSTR_LDR
%token INSTR_STRB
%token INSTR_LDRB
%token INSTR_B
%token INSTR_LSR

%%

program: 
	instruction newline program			
	| label instruction newline program		
	| label newline	program			
	| NEWLINE program
	|
	;

newline: 
	NEWLINE							{++linenumber;
						 		 if (linenumber > 256) {
									yyerror("se excede el espacio de memoria de instrucciones");
						 		 }}
	;

label: 
	ID							{if (first_pass) {
								 	if (exists_symb($<string>1) == 0) {
								 		process_sym($<string>1, linenumber);
									} else {
									  	yyerror("Ya se ha definido la etiqueta");
									}
						 		 }}
	;

cond:	
	COND							{cond_code = get_cond_code($<string>1);}
	|							{cond_code = 14;}
	;

set: 
	SET							{set = 1;}
	|							{set = 0;}
	;

Src2:	
	REGISTER						{reg_num = get_reg_num($<string>1);
								 src2 = load_register(reg_num);}
	| REGISTER ',' sh_inst immediate			{reg_num = get_reg_num($<string>1);
						 		 src2 = get_shifted(reg_num, $<ival>3, $<ival>4);}
	| immediate						{src2 = $<ival>1;}
	;

Src2_mem_sign: 
	Src2_mem						{src2 = src2 * 1;}
	| '-' Src2_mem						{src2 = src2 * -1;}
	;

Src2_mem:	
	REGISTER						{reg_num = get_reg_num($<string>1);
							 	 src2 = load_register(reg_num);}
	| REGISTER ',' sh_inst immediate			{reg_num = get_reg_num($<string>1);
							 	 src2 = get_shifted(reg_num, $<ival>3, $<ival>4);}
	| immediate						{src2 = $<ival>1;}
	;

Src2_sh: 
	REGISTER 						{reg_num = get_reg_num($<string>1);
								 src2 = load_register(reg_num);}
	| immediate						{src2 = $<ival>1;}
	;

immediate: 
	PRE NUM							{$<ival>$ = $<ival>2;}
	| PRE NUMH						{$<ival>$ = $<ival>2;}
	;	

sh_inst: 
	INSTR_LSL						{$<ival>$ = 0;}	
	| INSTR_LSR						{$<ival>$ = 1;}	
	| INSTR_ASR						{$<ival>$ = 2;}
	| INSTR_ROR						{$<ival>$ = 3;}
	;

mem_mode: 
	'[' reg_n ']'						{dir_mode = 0; src2 = 0;}
	| '[' reg_n ',' Src2_mem_sign ']'			{dir_mode = 1;}
	| '[' reg_n ',' Src2_mem_sign ']' '!'			{dir_mode = 2;}
	| '[' reg_n ']' ',' Src2_mem_sign			{dir_mode = 3;}			
	;

reg_d: 
	REGISTER						{rd = get_reg_num($<string>1);}
	;

reg_n: 
	REGISTER						{rn = get_reg_num($<string>1);}
	;

reg_m: 
	REGISTER						{rm = get_reg_num($<string>1);}
	;

reg_s: 
	REGISTER						{rs = get_reg_num($<string>1);}
	;

instruction: 
	instr_and				
	| instr_eor			
	| instr_sub			
	| instr_rsb			
	| instr_add			
	| instr_adc			
	| instr_sbc			
	| instr_rsc			
	| instr_cmp			
	| instr_cmn			
	| instr_orr			
	| instr_mov			
	| instr_lsl			
	| instr_asr			
	| instr_rrx			
	| instr_ror			
	| instr_bic			
	| instr_mvn			
	| instr_mul			
	| instr_mla			
	| instr_str			
	| instr_ldr			
	| instr_strb			
	| instr_ldrb			
	| instr_b			
	;


/*-------------------------------- DATOS ----------------------------------*/

instr_and: 
	INSTR_AND set cond reg_d ',' reg_n ',' Src2		{if (!first_pass) {
									printf("and\n");
								 	and(set, cond_code, rd, rn, src2);
									inst_count++; 
								 }}
	;

instr_eor: 
	INSTR_EOR set cond reg_d ',' reg_n ',' Src2		{if (!first_pass) {
									printf("eor\n");
								 	eor(set, cond_code, rd, rn, src2);
									inst_count++;
								 }}
	;
	
instr_sub: 
	INSTR_SUB set cond reg_d ',' reg_n ',' Src2		{if (!first_pass) {
									printf("sub\n");
								 	sub(set, cond_code, rd, rn, src2);
									inst_count++;
								 }}
	;
	
instr_rsb: 
	INSTR_RSB set cond reg_d ',' reg_n ',' Src2		{if (!first_pass) {
									printf("rsb\n");
									rsb(set, cond_code, rd, rn, src2);
									inst_count++;
								 }}
	;

instr_add: 
	INSTR_ADD set cond reg_d ',' reg_n ',' Src2		{if (!first_pass) {
									printf("add\n");
									add(set, cond_code, rd, rn, src2);
									inst_count++;
								 }}
	;

instr_adc: 
	INSTR_ADC set cond reg_d ',' reg_n ',' Src2		{if (!first_pass) {
									printf("adc\n");
								 	adc(set, cond_code, rd, rn, src2);
									inst_count++;
								 }}
	;

instr_sbc: 
	INSTR_SBC set cond reg_d ',' reg_n ',' Src2		{if (!first_pass) {
									printf("sbc\n");
								 	sbc(set, cond_code, rd, rn, src2);
									inst_count++;
								 }}
	;

instr_rsc: 
	INSTR_RSC set cond reg_d ',' reg_n ',' Src2		{if (!first_pass) {
									printf("rsc\n");
								 	rsc(set, cond_code, rd, rn, src2);
									inst_count++;
								 }}
	;

instr_cmp: 
	INSTR_CMP cond reg_n ',' Src2				{if (!first_pass) {	
									printf("cmp\n");
								 	cmp(cond_code, rn, src2);
									inst_count++;
								 }} 
	;

instr_cmn: 
	INSTR_CMN cond reg_n ',' Src2				{if (!first_pass) {
									printf("cmn\n");
								 	cmn(cond_code, rn, src2);
									inst_count++;
								 }} 
	;

instr_orr: 
	INSTR_ORR set cond reg_d ',' reg_n ',' Src2		{if (!first_pass) {
									printf("orr\n");
								 	orr(set, cond_code, rd, rn, src2);
									inst_count++;
								 }}
	;

instr_mov: 
	INSTR_MOV set cond reg_d ',' Src2			{if (!first_pass) {
									printf("mov\n");
								 	mov(set, cond_code, rd, src2);
									inst_count++;
								 }}
	;

instr_lsl: 
	INSTR_LSL set cond reg_d ',' reg_m ',' Src2_sh		{if (!first_pass) {
									printf("lsl\n");
								 	lsl(set, cond_code, rd, rm, src2);
									inst_count++;
								 }}
	;

instr_asr: 
	INSTR_ASR set cond reg_d ',' reg_m ',' Src2_sh		{if (!first_pass) {
									printf("asr\n");
								 	asr(set, cond_code, rd, rm, src2);
									inst_count++;
								 }}
	;

instr_rrx: 
	INSTR_RRX set cond reg_d ',' reg_m			{if (!first_pass) {
									printf("rrx\n");
								 	rrx(set, cond_code, rd, rm);
									inst_count++;
								 }} 
	;

instr_ror: 
	INSTR_ROR set cond reg_d ',' reg_m ',' Src2_sh		{if (!first_pass) {
									printf("ror\n");
								 	ror(set, cond_code, rd, rm, src2);
									inst_count++;
								 }}
	;

instr_bic: 
	INSTR_BIC set cond reg_d ',' reg_n ',' Src2		{if (!first_pass) {
									printf("bic\n");
								 	bic(set, cond_code, rd, rn, src2);
									inst_count++;
								 }}
	;

instr_mvn: 
	INSTR_MVN set cond reg_d ',' Src2			{if (!first_pass) {
									printf("mvn\n");
								 	mvn(set, cond_code, rd, src2);
									inst_count++;
								 }}
	;

/*--------------------------- MULTIPLICACIÓN ------------------------------*/

instr_mul: 
	INSTR_MUL set cond reg_n ',' reg_m ',' reg_s		{if (!first_pass) {
									printf("mul\n");
								 	mul(set, cond_code, rn, rm, rs);
									inst_count++;
								 }} 
	;
			
instr_mla: 
	INSTR_MLA set cond reg_n ',' reg_m ',' reg_s ',' reg_d	{if (!first_pass) {
									printf("mla\n");
								 	mla(set, cond_code, rn, rm, rs, rd);
									inst_count++;
								 }} 
	;

/*------------------------------- MEMORIA ---------------------------------*/

instr_str: 
	INSTR_STR cond reg_d ',' mem_mode			{if (!first_pass) {
									printf("str\n");
								 	str(cond_code, rd, rn, src2, dir_mode);
									inst_count++;
								 }}
	;

instr_ldr: 
	INSTR_LDR cond reg_d ',' mem_mode			{if (!first_pass) {
									printf("ldr\n");
								 	ldr(cond_code, rd, rn, src2, dir_mode);
									inst_count++;
								 }}
	;

instr_strb: 
	INSTR_STRB cond reg_d ',' mem_mode			{if (!first_pass) {
									printf("strb\n");
								 	strb(cond_code, rd, rn, src2, dir_mode);
									inst_count++;
								 }}
	;

instr_ldrb: 
	INSTR_LDRB cond reg_d ',' mem_mode			{if (!first_pass) {
									printf("ldrb\n");
								 	ldrb(cond_code, rd, rn, src2, dir_mode);
									inst_count++;
								 }}
	;

/*-------------------------------- SALTOS ---------------------------------*/

instr_b	: 
	INSTR_B cond ID						{if (!first_pass) {
								 	br_str = $<string>3;
						 			branch_ctrl = 1;
									branch_cond = b(cond_code);
									inst_count++;
						 			printf("branch %s\n", br_str);
								 }}			
	;

%%

/*Función que verifica si existe un elemento cuyo campo "nombre" coincide con el
argumento str. Si existe se retorna un uno, de lo contrario un cero.*/

int exists_symb(char* str){
	struct std_sym* sp;
  	for(sp = symtable; sp < &symtable[SYMB]; sp++) {
		if(sp->nombre && strcmp(sp->nombre, str) == 0 ){
			return 1;
		}
	}
	return 0;
}

/*Retorna el código de condición a partir de la representación literal de la
  misma (cond_str) (AL -> 14)*/

int get_cond_code(char* cond_str){
	str_tolower(cond_str);
	//printf("Cond: %s", cond_str);
	int cond_code = 0;
	if (strcmp(cond_str, "eq") == 0) 
		{
		  cond_code = 0;		//cond = 0000
		}   
	else if (strcmp(cond_str, "ne") == 0) 
		{
		  cond_code = 1;		//cond = 0001
		} 
	else if (strcmp(cond_str, "hs") == 0) 
		{
		  cond_code = 2;		//cond = 0010
		} 
	else if (strcmp(cond_str, "lo") == 0) 
		{
		  cond_code = 3;		//cond = 0011
		} 
	else if (strcmp(cond_str, "mi") == 0) 
		{
		  cond_code = 4;		//cond = 0100
		} 
	else if (strcmp(cond_str, "pl") == 0) 
		{
		  cond_code = 5;		//cond = 0101
		} 
	else if (strcmp(cond_str, "vs") == 0) 
		{
		  cond_code = 6;		//cond = 0110
		} 
	else if (strcmp(cond_str, "vc") == 0) 
		{
		  cond_code = 7;		//cond = 0111
		} 
	else if (strcmp(cond_str, "hi") == 0) 
		{
		  cond_code = 8;		//cond = 1000
		} 
	else if (strcmp(cond_str, "ls") == 0) 
		{
		  cond_code = 9;		//cond = 1001
		} 
	else if (strcmp(cond_str, "ge") == 0) 
		{
		  cond_code = 10;		//cond = 1010
		} 
	else if (strcmp(cond_str, "lt") == 0) 
		{
		  cond_code = 11;		//cond = 1011
		} 
	else if (strcmp(cond_str, "gt") == 0) 
		{
		  cond_code = 12;		//cond = 1100
		} 
	else if (strcmp(cond_str, "le") == 0) 
		{
		  cond_code = 13;		//cond = 1101
		} 
	else if (strcmp(cond_str, "al") == 0) 
		{
		  cond_code = 14;		//cond = 1110
		} 
	return cond_code;
}

/*Retorna el número de registro a partir de su representación literal (reg_str).
  (R10 -> 10)*/

int get_reg_num(char* reg_str){
	str_tolower(reg_str);
	int reg_num = 0;
	if (strcmp(reg_str, "r0") == 0) 
		{
		  reg_num = 0;
		}   
	else if (strcmp(reg_str, "r1") == 0) 
		{
		  reg_num = 1;
		} 
	else if (strcmp(reg_str, "r2") == 0) 
		{
		  reg_num = 2;
		} 
	else if (strcmp(reg_str, "r3") == 0) 
		{
		  reg_num = 3;
		} 
	else if (strcmp(reg_str, "r4") == 0) 
		{
		  reg_num = 4;
		} 
	else if (strcmp(reg_str, "r5") == 0) 
		{
		  reg_num = 5;
		} 
	else if (strcmp(reg_str, "r6") == 0) 
		{
		  reg_num = 6;
		} 
	else if (strcmp(reg_str, "r7") == 0) 
		{
		  reg_num = 7;
		} 
	else if (strcmp(reg_str, "r8") == 0) 
		{
		  reg_num = 8;
		} 
	else if (strcmp(reg_str, "r9") == 0) 
		{
		  reg_num = 9;
		} 
	else if (strcmp(reg_str, "r10") == 0) 
		{
		  reg_num = 10;
		} 
	else if (strcmp(reg_str, "r11") == 0) 
		{
		  reg_num = 11;
		} 
	else if (strcmp(reg_str, "r12") == 0) 
		{
		  reg_num = 12;
		} 
	else if (strcmp(reg_str, "r13") == 0) 
		{
		  reg_num = 13;
		  yyerror("Registro inválido (SP)");
		} 
	else if (strcmp(reg_str, "r14") == 0) 
		{
		  reg_num = 14;
		} 
	else if (strcmp(reg_str, "r15") == 0) 
		{
		  reg_num = 15;
		  yyerror("Registro inválido (PC)");
		} 
	return reg_num;
}

/*Abre los archivos respectivos y los asigna al puntero
  correspondiente. El argumento es el nombre del archivo
  de entrada. Retorna el nombre del archivo de salida en
  ensamblador*/

void init_files(char *inputfn) {
	inputf = fopen(inputfn , "r");
	if (!inputf) {
		printf("Error: Archivo inválido.\n");
		exit(-1);
	}
	err_file = fopen("Módulo de Errores.txt", "w");
	return;
}

/*Procesa todas las instrucciones branch en el código fuente. Para ello se 
  obtienen las etiquetas de salto para cada una de esas instrucciones y se 
  comparan con las etiquetas en la tabla de símbolos, para luego codificar
  las etiquetas usando PC_salto - (PC_actual + 8) >> 2*/

void process_branches(){
	int pc_act;
	int pc_dest;
	int imm;
	int br_code;
	struct branches* bt;
	struct std_sym* sp;
	for(bt = branch_table; bt < &branch_table[BRANCH]; bt++) {
		if(bt->label){
			if(exists_symb(bt->label) == 1){
			 	sp = search(bt->label);
				br_code = bt->code;
				pc_act = (bt->dir-1)*4;
				pc_dest = (sp->dir-1)*4;		
				imm = (pc_dest-(pc_act+8))>>2;		
				imm = imm & 0xFFFFFF;				
				br_code = br_code | imm;
				if(!fseek(asm_output, (bt->dir-1)*9, SEEK_SET)){ 

				} else {
					printf("Imposible sobreescribir");
				}
			} else {
				yyerror("No existe la etiqueta");
			}
		} else {
			return;
		}
  	}
}

/*Para procesar un símbolo se obtiene una entrada vacía en la tabla de símbolos
y se le asigna el argumento correspondiente a cada espacio:
name a "nombre", lineno a "linea", use a "uso" pparam a "param" y pfunc a "func".
Adicionalmente, esta función se podría utilizar para modificar una entrada 
existente en la tabla de símbolos.*/

void process_sym(char* name, int mem_dir){
	struct std_sym *tmp = symlook(name);
	tmp->dir = mem_dir;	
}

/*Función de búsqueda. Se busca una entrada cuyo campo "nombre"
coincida con el argumento s, si existe, se retorna un puntero a dicha entrada, 
si no, se retorna la última entrada de la tabla. Se debe tener precaución,
pues si no existe la entrada que se busca, se retorna la última, lo que podría
ocasionar un comportamiento errático del programa. Es recomendable utilizar
esta función en conjunto con existsSymb, para asegurarse de que la entrada 
existe.*/

struct std_sym* search(char* s){ 
	struct std_sym* sp;
  	for(sp = symtable; sp < &symtable[SYMB]; sp++) {
		if(sp->nombre && (strcmp(sp->nombre, s) == 0))
			return sp;
		}
	return sp;
}

/*Convierte su entrada (string) a una cadena de caracteres en minúscula. */

char* str_tolower(char* string){
	for ( ; *string; ++string) *string = tolower(*string);
	return string;
}

/*Función de inserción y edición de la tabla. Se busca una entrada cuyo campo "nombre"
coincida con el argumento s, si existe, se retorna un puntero a dicha entrada, si no
se crea una entrada con el argumento s en el campo "nombre" y se retorna un puntero
a la entrada recién creada.
Existe un error si se excede la capacidad de la tabla.*/

struct std_sym * symlook(char* s){ 		
	struct std_sym* sp;
  	for(sp = symtable; sp < &symtable[SYMB]; sp++) {
		if(sp->nombre && (strcmp(sp->nombre, s) == 0)){
			return sp;
		}
		if(!sp->nombre){ 
			sp->nombre = strdup(s);
			return sp;
		}
  	}
  	yyerror("Las variables exceden la capacidad de la tabla de símbolos.");
  	exit(1);
}

/*Función de manejo de errores por defecto de yacc. La entrada es el mensaje que se desea dar
  cuando ocurre un error. En este caso se implementó de manera tal que se impriman todos los 
  mensajes en un archivo de texto.*/

void yyerror (const char* s) {
	if(err_bool == 0) err_bool = 1;
	fprintf(err_file,"Error en la línea %d. Error: %s.\n",linenumber, s);
} 

/* Obtiene el valor que está almacenado en un registro y le aplica el desplazamiento
   o rotación correspondiente */

int get_shifted(int reg_num, int sh_inst, int inmediate)
{
	int shifted = 0;
	if (sh_inst == 0) {shifted = shift_left(reg_num, inmediate);}
	else if (sh_inst == 1) {shifted = shift_right(reg_num, inmediate);}
	else if (sh_inst == 2) {shifted = shift_right(reg_num, inmediate);}
	else if (sh_inst == 3) {shifted = rotate_right(reg_num, inmediate);}
	return shifted;
}

void estimate_time(int count)
{
	float time = count * 10;
	if (time >= 1000000)
	{
		time = time / 1000000;
		printf("Tiempo aproximado de ejecución: %f s\n", time);
	}
	else if (time >= 1000)
	{
		time = time / 1000;
		printf("Tiempo aproximado de ejecución: %f ms\n", time);
	}
	else
	{
		printf("Tiempo aproximado de ejecución: %f µs\n", time);
	}
}

/*Función principal. Primero se inicializan todos los archivos, con sus respectivas cabeceras.
  Luego se evalúan el archivo de entrada, token por token, hasta agotarlos. Cada vez que coincide
  una regla se ejecutan las acciones que se encuentran a la derecha. Si se provee el argumento -p
  se imprime la tabla de símbolos al archivo "TablaSímbolos.txt". Si existe algún error, se indica 
  mediante un mensaje en consola y se escribe al archivo "Módulo de Errores.txt" y no se genera 
  la salida en ensamblador. Si no hay errores se indica que se realizó la compilación con éxito.*/

int main(int argc, char **argv) {
	init();
	char line[30];
	struct std_sym* sp;
	init_files(argv[1]);
	yyin = inputf;
	YY_BUFFER_STATE buffer;
	do {
    		yyparse();
	} while (!feof(yyin));
	first_pass = 0;
	linenumber = 1;
	printf("FP\n");
	fseek(inputf, 0, SEEK_SET);
	fgets(line, 30, inputf);
	buffer = yy_scan_string(line);
	yy_switch_to_buffer(buffer);
	do {
		buffer = yy_scan_string(line);
		yyparse();
		if (branch_ctrl && branch_cond) {				// Si debe hacer el salto
			if(exists_symb(br_str) == 1) {				// Si existe la etiqueta
				sp = search(br_str);
        			fseek(inputf, 0, SEEK_SET);
        			for (int i = 1; i <=  sp->dir; ++i) {
          				fgets(line, 30, inputf);
        			}
      			} else {
        			yyerror("No existe la etiqueta");        
        			break;
      			}    
      			branch_ctrl = 0;
      			branch_cond = 0;
    		}
		fgets(line, 30, inputf);
		buffer = yy_scan_string(line);
	} while (!feof(inputf));
	yy_delete_buffer(buffer);
	if (err_bool == 1) {
		fclose(asm_output);
		remove("out.txt");
		printf("Error durante la compilación. Ver Módulo de Errores.txt.\n");
		fclose(err_file);
		return 1;
	}
	fprintf(err_file, "¡No hay errores en el archivo %s!", argv[1]);
	fclose(err_file);
	fclose(inputf);
	printf("Simulado exitosamente.\n\n");
	print_regs();
	printf("\n");
	print_memory();
	printf("\n");
	print_flags();
	estimate_time(inst_count);
	foo();
	return 0;
}
