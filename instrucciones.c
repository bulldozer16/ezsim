#include <stdio.h>
#include <stdlib.h>

/* Banderas utilizadas en la arquitectura ARMv4 */

int n, z, c, v = 0;

/* Punteros a memoria que simulan la memoria de programa, 
   memoria de datos y banco de registros */

void *memory = 0;
void *regs = 0;

/* Asigna la bandera N */

void set_n(int result)
{
	n = result < 0 ? 1 : 0;
}

/* Asigna la bandera Z */

void set_z(int result)
{
	z = result == 0 ? 1 : 0;
}

/* Asigna la bandera C en caso de suma */

void set_c_add(int value, int src2)
{
	int x = value + src2;
	long int y = value + src2;
	c = x == y ? 0 : 1;
}

/* Asigna la bandera C en caso de resta */

void set_c_sub(int value, int src2)
{
	int x = value - src2;
	c = x >= 0 ? 1 : 0;
}

/* Asigna la bandera C en caso de shift o rotación.
   ASR = 0, LSL = 1, ROR = 2. */

void set_c_shift(int value, int shamt, int opcode)
{
	if (opcode == 0)
	{
		if (shamt > 0)
		{
			shamt = shamt - 1;
			value = value >> shamt;
			c = value & 0x1;
		}
	}
	else if (opcode == 1)
	{
		if (shamt > 0)
		{
			shamt = shamt - 1;
			value = value << shamt;
			value = value & 0x80000000;
			value = value >> 31;
			c = value & 0x1;
		}
	}
	else if (opcode == 2)
	{
		if (shamt > 0)
		{
			shamt = shamt - 1;
			value = ((int)((unsigned int)value >> shamt)) | (value << (32 - shamt));
			c = value & 0x1;
		}
	}
}

/* Asigna la bandera V en caso de suma */

void set_v_add(int value, int src2)
{
	if (value < 0 && src2 < 0)
	{
		int x = value + src2;
		v = x > 0 ? 1 : 0;	
	}
	else if (value > 0 && src2 > 0)
	{
		int x = value + src2;
		v = x < 0 ? 1 : 0;
	}
	else
	{
		v = 0;
	}
}

/* Asigna la bandera V en caso de resta */

void set_v_sub(int value, int src2)
{
	if (value < 0 && src2 > 0)
	{
		int x = value - src2;
		v = x > 0 ? 1 : 0;	
	}
	else if (value > 0 && src2 < 0)
	{
		int x = value - src2;
		v = x < 0 ? 1 : 0;
	}
	else
	{
		v = 0;
	}
}

/* Imprime las banderas */

void print_flags()
{
	printf("Negative: %d\nZero: %d\nCarry: %d\nOverflow: %d\n", n, z, c, v);
}

/* Imprime la memoria de programa y la memoria de datos */

void print_memory()
{
	printf("======== Memoria de programa ========\n\n");
	int *ptr = (int*) memory;
	int i;

	for (i = 0; i < 256; i++)
	{
		printf("0x%x\t0x%x\n", i * 4, *(ptr + i));
	}

	printf("\n======== Memoria de datos ========\n\n");

	for (i = 256; i < 512; i++)
	{
		printf("0x%x\t0x%x\n", i * 4, *(ptr + i));
	}
}

/* Imprime el banco de registros */

void print_regs()
{
	printf("======== Registros ========\n\n");
	int *ptr = (int*) regs;
	int i;

	for (i = 0; i < 16; i++)
	{
		printf("R%d\t0x%x\n", i, *(ptr + i));
	}
}

/* Guarda un valor en una posición de memoria */

void store_memory(int address, int value)
{
	int *ptr = (int*) memory;
	*(ptr + address) = value;
}

/* Obtiene un valor de una posición de memoria */

int load_memory(int address)
{
	int *ptr = (int*) memory;
	int value = *(ptr + address);
	return value;
}

/* Obtiene el valor almacenado en un registro */

int load_register(int reg)
{
	if (reg < 16)
	{
		int *ptr = (int*) regs;
		int value = *(ptr + reg);
		return value;
	}
	return 0;
}

/* Almacena un valor en un registro */

void store_register(int reg, int value)
{
	if (reg < 16)
	{
		int *ptr = (int*) regs;
		*(ptr + reg) = value;
	}
}

/* Obtiene el valor de un registro y le realiza un desplazamiento
   a la izquierda */

int shift_left(int reg, int shamt) 
{
	int value = load_register(reg);
	int shifted = value << shamt;
	return shifted;
}

/* Obtiene el valor de un registro y le realiza un desplazamiento
   a la derecha */

int shift_right(int reg, int shamt) 
{
	int value = load_register(reg);
	int shifted = value >> shamt;
	return shifted;
}

/* Obtiene el valor de un registro y le realiza una rotación
   a la derecha */

int rotate_right(int reg, int shamt) 
{
	int value = load_register(reg);
	int rotated = ((int)((unsigned int)value >> shamt)) | (value << (32 - shamt));
	//int rotated = (value >> shamt) | (value << (32 - shamt));
	return rotated;
}

/* Bitwise AND */

void and(int set, int cond, int rd, int rn, int src2) 
{
	int exec = eval_cond(cond);
	if (exec)
	{
		int value = load_register(rn);
		int result = value & src2;
		store_register(rd, result);
		if (set)
		{
			set_n(result);
			set_z(result);
		}
	}
}

/* Bitwise XOR */

void eor(int set, int cond, int rd, int rn, int src2) 
{
	int exec = eval_cond(cond);
	if (exec)
	{
		int value = load_register(rn);
		int result = value ^ src2;
		store_register(rd, result);
		if (set)
		{
			set_n(result);
			set_z(result);
		}
	}
}

/* Subtract */

void sub(int set, int cond, int rd, int rn, int src2) 
{
	int exec = eval_cond(cond);
	if (exec)
	{
		int value = load_register(rn);
		int result = value - src2;
		store_register(rd, result);
		if (set)
		{
			set_n(result);
			set_z(result);
			set_c_sub(value, src2);
			set_v_sub(value, src2);
		}
	}
}

/* Reverse Subtract */

void rsb(int set, int cond, int rd, int rn, int src2) 
{
	int exec = eval_cond(cond);
	if (exec)
	{
		int value = load_register(rn);
		int result = src2 - value;
		store_register(rd, result);
		if (set)
		{
			set_n(result);
			set_z(result);
			set_c_sub(src2, value);
			set_v_sub(src2, value);
		}
	}
}

/* Add */

void add(int set, int cond, int rd, int rn, int src2) 
{
	int exec = eval_cond(cond);
	if (exec)
	{
		int value = load_register(rn);
		int result = value + src2;
		store_register(rd, result);
		if (set)
		{
			set_n(result);
			set_z(result);
			set_c_add(value, src2);
			set_v_add(value, src2);
		}
	}
}

/* Add with Carry */

void adc(int set, int cond, int rd, int rn, int src2) 
{
	int exec = eval_cond(cond);
	if (exec)
	{
		int value = load_register(rn);
		int result = value + src2 + c;
		store_register(rd, result);
		if (set)
		{
			set_n(result);
			set_z(result);
			src2 = src2 + c;
			set_c_add(value, src2);
			set_v_add(value, src2);
		}
	}
}

/* Subtract with Carry */

void sbc(int set, int cond, int rd, int rn, int src2) 
{
	int exec = eval_cond(cond);
	if (exec)
	{
		int value = load_register(rn);
		int result = value - src2 - !c;
		store_register(rd, result);
		if (set)
		{
			set_n(result);
			set_z(result);
			src2 = src2 + !c;
			set_c_sub(value, src2);
			set_v_sub(value, src2);
		}
	}
}

/* Reverse Subtract with Carry */

void rsc(int set, int cond, int rd, int rn, int src2) 
{
	int exec = eval_cond(cond);
	if (exec)
	{
		int value = load_register(rn);
		int result = src2 - value - !c;
		store_register(rd, result);
		if (set)
		{
			set_n(result);
			set_z(result);
			value = value + !c;
			set_c_sub(src2, value);
			set_v_sub(src2, value);
		}
	}
}

/* Compare */

void cmp(int cond, int rn, int src2) 
{
	int exec = eval_cond(cond);
	if (exec)
	{
		int value = load_register(rn);
		int result =  value - src2;
		set_n(result);
		set_z(result);
		set_c_sub(value, src2);
		set_v_sub(value, src2);
	}
}

/* Compare Negative */

void cmn(int cond, int rn, int src2) 
{
	int exec = eval_cond(cond);
	if (exec)
	{
		int value = load_register(rn);
		int result =  value + src2;
		set_n(result);
		set_z(result);
		set_c_add(value, src2);
		set_v_add(value, src2);
	}
}

/* Bitwise OR */

void orr(int set, int cond, int rd, int rn, int src2) 
{
	int exec = eval_cond(cond);
	if (exec)
	{
		int value = load_register(rn);
		int result = value | src2;
		store_register(rd, result);
		if (set)
		{
			set_n(result);
			set_z(result);
		}
	}
}

/* Move */

void mov(int set, int cond, int rd, int src2) 
{
	int exec = eval_cond(cond);
	if (exec)
	{
		store_register(rd, src2);
		if (set)
		{
			set_n(src2);
			set_z(src2);
		}
	}
}

/* Logical Shift Left */

void lsl(int set, int cond, int rd, int rm, int shamt) 
{
	int exec = eval_cond(cond);
	if (exec)
	{
		int value = load_register(rm);
		int shifted = value << shamt;
		store_register(rd, shifted);
		if (set)
		{
			set_n(shifted);
			set_z(shifted);
			set_c_shift(value, shamt, 1);
		}
	}
}

/* Arithmetic Shift Right */

void asr(int set, int cond, int rd, int rm, int shamt) 
{
	int exec = eval_cond(cond);
	if (exec)
	{
		int value = load_register(rm);
		int shifted = value >> shamt;
		store_register(rd, shifted);
		if (set)
		{
			set_n(shifted);
			set_z(shifted);
			set_c_shift(value, shamt, 0);
		}
	}
}

/* Rotate Right Extend */

void rrx(int set, int cond, int rd, int rm) 
{
	int exec = eval_cond(cond);
	if (exec)
	{
		int value = load_register(rm);
		int bit0 = value & 1;
		value = value >> 1;
		int bit31 = c;
		int result = 0;
		if (bit31 == 0)
		{
			bit31 = 1;
			bit31 = bit31 << 31;
			bit31 = ~bit31;
			result = value & bit31;
		}
		else
		{
			bit31 = bit31 << 31;
			result = value | bit31;
		}
		store_register(rd, result);
		if (set)
		{
			set_n(result);
			set_z(result);
			c = bit0;
		}
	}
}

/* Rotate Right */

void ror(int set, int cond, int rd, int rm, int shamt) 
{
	int exec = eval_cond(cond);
	if (exec)
	{
		int value = load_register(rm);
		int rotated = ((int)((unsigned int)value >> shamt)) | (value << (32 - shamt));
		store_register(rd, rotated);
		if (set)
		{
			set_n(rotated);
			set_z(rotated);
			set_c_shift(value, shamt, 2);
		}
	}
}

/* Bitwise Clear */

void bic(int set, int cond, int rd, int rn, int src2) 
{
	int exec = eval_cond(cond);
	if (exec)
	{
		int value = load_register(rn);
		int result = value & ~src2;
		store_register(rd, result);
		if (set)
		{
			set_n(result);
			set_z(result);
		}
	}
}

/* Bitwise NOT */

void mvn(int set, int cond, int rd, int src2) 
{
	int exec = eval_cond(cond);
	if (exec)
	{
		src2 = ~src2;
		store_register(rd, src2);
		if (set)
		{
			set_n(src2);
			set_z(src2);
		}
	}
}

/* Multiply */

void mul(int set, int cond, int rd, int rn, int rm) 
{
	int exec = eval_cond(cond);
	if (exec)
	{
		int value = load_register(rn);
		int value2 = load_register(rm);
		int result = value * value2;
		store_register(rd, result);
		if (set)
		{
			set_n(result);
			set_z(result);
		}
	}
}

/* Multiply Accumulate */

void mla(int set, int cond, int rd, int rn, int rm, int ra) 
{
	int exec = eval_cond(cond);
	if (exec)
	{
		int value = load_register(rn);
		int value2 = load_register(rm);
		int value3 = load_register(ra);
		int result = (value * value2) + value3;
		store_register(rd, result);
		if (set)
		{
			set_n(result);
			set_z(result);
		}
	}
}

/* Store Register */

void str(int cond, int rd, int rn, int src2, int mode) 
{
	int exec = eval_cond(cond);
	if (exec)
	{
		int base = load_register(rn);
		int address = base + src2;
		if (mode == 2)
		{
			store_register(rn, address);
		}
		if (mode == 3)
		{
			store_register(rn, address);
			address = base;
		}
		if (address % 4 == 0)
		{
			address = address / 4;
			if (address >= 256 && address <= 511)
			{
				int value = load_register(rd);
				store_memory(address, value);
			}
		}
		else
		{
			printf("Dirección inválida\n");
		}
	}
}

/* Load Register */

void ldr(int cond, int rd, int rn, int src2, int mode) 
{
	int exec = eval_cond(cond);
	if (exec)
	{
		int base = load_register(rn);
		int address = base + src2;
		if (mode == 2)
		{
			store_register(rn, address);
		}
		if (mode == 3)
		{
			store_register(rn, address);
			address = base;
		}
		if (address % 4 == 0)
		{
			address = address / 4;
			if (address >= 256 && address <= 511)
			{
				int value = load_memory(address);
				store_register(rd, value);
			}
		}
		else
		{
			printf("Dirección inválida\n");
		}
	}
}

/* Store Byte */

void strb(int cond, int rd, int rn, int src2, int mode) 
{
	int exec = eval_cond(cond);
	if (exec)
	{
		int value = load_register(rd);
		value = value & 0xff;
		int base = load_register(rn);
		int address = base + src2;
		if (mode == 2)
		{
			store_register(rn, address);
		}
		if (mode == 3)
		{
			store_register(rn, address);
			address = base;
		}
		int byte_num = address & 0x3;
		value = value << (8 * byte_num);
		int mask = 0xff << (8 * byte_num);
		mask = ~mask;
		address = (address - byte_num) / 4;
		if (address >= 256 && address <= 511)
		{
			int word = load_memory(address);
			word = word & mask;
			word = word | value;
			store_memory(address, word);
		}
	}
}

/* Load Byte */

void ldrb(int cond, int rd, int rn, int src2, int mode) 
{
	int exec = eval_cond(cond);
	if (exec)
	{
		int base = load_register(rn);
		int address = base + src2;
		if (mode == 2)
		{
			store_register(rn, address);
		}
		if (mode == 3)
		{
			store_register(rn, address);
			address = base;
		}
		int byte_num = address & 0x3;
		address = (address - byte_num) / 4;
		if (address >= 256 && address <= 511)
		{
			int word = load_memory(address);
			word = word >> (8 * byte_num);
			word = word & 0xff;
			store_register(rd, word);
		}
	}
}

/* Branch */

int b(int cond) 
{
	return eval_cond(cond);
}

/* Asigna la memoria para la memoria de programa, memoria de
   datos y banco de registros. Además asigna la dirección 0x7FC
   al registro 13 (SP). */

int init()
{
	memory = calloc(512, sizeof(int));
	regs = calloc(16, sizeof(int));

	int *ptr = (int*) regs;
	*(ptr + 13) = 2044;

	return 0;
}

/* Libera la memoria al finalizar el programa */

int foo()
{
	free(memory);
	free(regs);

	return 0;
}

/* Evalúa una condición con respecto al estado de las banderas.
   Retorna 1 si debe ejecutar y 0 en el caso contrario. */

int eval_cond(int cond_code)
{
	int execute = 0;
	if (cond_code == 0)
	{
		execute = z == 1 ? 1 : 0;
	}
	else if (cond_code == 1)
	{
		execute = z == 0 ? 1 : 0;
	}
	else if (cond_code == 2)
	{
		execute = c == 1 ? 1 : 0;
	}
	else if (cond_code == 3)
	{
		execute = c == 0 ? 1 : 0;
	}
	else if (cond_code == 4)
	{
		execute = n == 1 ? 1 : 0;
	}
	else if (cond_code == 5)
	{
		execute = n == 0 ? 1 : 0;
	}
	else if (cond_code == 6)
	{
		execute = v == 1 ? 1 : 0;
	}
	else if (cond_code == 7)
	{
		execute = v == 0 ? 1 : 0;
	}
	else if (cond_code == 8)
	{
		int x = ~z & c;
		execute = x == 1 ? 1 : 0;
	}
	else if (cond_code == 9)
	{
		int x = z | ~c; 
		execute = x == 1 ? 1 : 0;
	}
	else if (cond_code == 10)
	{
		int x = ~(n ^ v);
		execute = x == 1 ? 1 : 0;
	}
	else if (cond_code == 11)
	{
		int x = n ^ v;
		execute = x == 1 ? 1 : 0;
	}
	else if (cond_code == 12)
	{
		int x = ~(n ^ v) & ~z; 
		execute = x == 1 ? 1 : 0;
	}
	else if (cond_code == 13)
	{
		int x = z | (n ^ v);
		execute = x == 1 ? 1 : 0;
	}
	else if (cond_code == 14)
	{
		execute = 1;
	}
	return execute;
}
