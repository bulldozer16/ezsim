/* 
 * File:   ezsim.h
 * Author: Sergio Vargas
 *
 * Created on 10 de marzo de 2016, 02:02
 */

#include <ctype.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int data_reg_code(char*, char);

int encode_immediate(int);

int encode_imm_mem(int);

int encode_imm_sh(int);

int encode_register(char*, int, int);

int exists_symb(char*);

int get_cond_code(char*);

int get_reg_num(char*);

void init_files(char* );

void process_branches();

void process_sym(char*, int);

int rotate_left(int, int);

struct std_sym* search(char*);

char* str_tolower(char*);

struct std_sym* symlook(char*);

void yyerror (const char*);

