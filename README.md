# MicroEdu-8

Computador educacional de 8 bits, construído do zero em Verilog para a placa
**DE1-SoC** (Cyclone V 5CSEMA5F31C6), com **bootloader** próprio, **mini sistema
operacional com menu** e **assembler** em Python.

Projeto Garagem: "do bit ao jogo" — Pós-graduação em Computação Aplicada,
IFSP Guarulhos. Autora: Giselle Creuza Silva.

## Estado atual

| Parte | Situação |
|---|---|
| CPU (microcódigo, 18 instruções) | pronta, testada em simulação |
| Bootloader (ROM) | pronto, testado em simulação |
| Sistema com menu: soma e subtração | pronto, testado em simulação |
| Assembler (`montador.py`) | pronto |
| Teste na placa real | pendente (a placa fica no laboratório) |
| Programa de demonstração final | em andamento |

## Como funciona (visão geral)

1. Ao ligar, a CPU executa o **bootloader**, que está gravado na ROM.
2. O bootloader mostra `b0`, confere a assinatura `5A` da imagem do sistema,
   copia a imagem do "armazenamento" (ROM) para a RAM e pula para ela.
   Se a imagem for inválida, mostra `EE` e para.
3. O sistema mostra o menu (`F0`). Você escolhe a opção nas chaves e confirma
   com o botão ENTER:
   - opção `1`: soma de dois números;
   - opção `2`: subtração de dois números;
   - outra opção: volta ao menu.
4. A calculadora pede o 1º número (`A1`), o 2º número (`A2`) e mostra o
   resultado. ENTER volta ao menu.

## Entradas e saídas (DE1-SoC)

| Elemento | Função |
|---|---|
| KEY0 | dá um passo (um clock da CPU) |
| KEY1 | reset |
| KEY2 | ENTER (confirma o que está nas chaves) |
| SW0–SW7 | entrada de dados (instrução `IN`) |
| SW9 | 1 = executa sozinho; 0 = só por botão |
| SW8 | 1 = automático rápido (250x) |
| HEX3:HEX2 | registrador de saída (instrução `OUT`) |
| HEX1:HEX0 | acumulador A |
| LEDR0–7 | acumulador A em binário |
| LEDR8 | acende quando a CPU executou `HLT` |
| LEDR9 | muda a cada passo |

## Arquitetura

CPU de 8 bits no estilo SAP-1 estendido, com **barramento único**, **contador de
passos T** e **controle por microcódigo** (palavra de controle de 17 bits).
Registradores: A (acumulador), B, PC, MAR, IR e registrador de saída.

### Conjunto de instruções

Cada instrução tem 2 bytes: opcode e operando.

| Opcode | Mnemônico | Efeito |
|---|---|---|
| 00 | `HLT` | para a CPU |
| 01 | `LDI n` | A ← n |
| 02 | `ADDI n` | A ← A + n |
| 03 | `SUBI n` | A ← A − n |
| 04 | `LDA a` | A ← M[a] |
| 05 | `STA a` | M[a] ← A |
| 06 | `ADD a` | A ← A + M[a] |
| 07 | `SUB a` | A ← A − M[a] |
| 08 | `JMP a` | PC ← a |
| 09 | `JZ a` | se A = 0, PC ← a |
| 0A | `JNZ a` | se A ≠ 0, PC ← a |
| 0B | `IN` | A ← chaves SW[7:0] |
| 0C | `OUT` | saída ← A |
| 0D | `LDN a` | A ← M[M[a]] (endereço indireto) |
| 0E | `STN a` | M[M[a]] ← A (endereço indireto) |
| 0F | `JMPN a` | PC ← M[a] (usado para voltar de sub-rotinas) |
| 10 | `INK` | A ← 1 se ENTER foi apertado desde a última leitura, senão 0 |

O assembler também aceita as pseudo-instruções `CALL alvo` e `RET`
(sub-rotinas de um nível).

### Mapa de memória

| Endereços | Uso |
|---|---|
| 00–37 | ROM: bootloader |
| 38–97 | ROM: armazenamento (imagem do sistema: `5A`, tamanho, código) |
| 98–F7 | RAM do sistema (a imagem é copiada para cá e roda daqui) |
| F8–FF | RAM de variáveis |

## Estrutura do repositório

```
hdl/microedu8_top.v     CPU + topo para a placa (Verilog)
software/montador.py    assembler (Python 3)
software/rom.asm        bootloader + sistema com menu
software/dobro.asm      exemplo simples
```

## Como usar

### Simulador / placa

1. Carregue `hdl/microedu8_top.v` no simulador (ou compile no Quartus para a
   DE1-SoC).
2. Ligue SW9 e SW8 (execução automática rápida) e dê reset (KEY1).
3. Espere `b0` virar `F0` (o boot copia o sistema para a RAM).
4. Ponha o número da opção nas chaves e aperte KEY2.

Observação: no simulador, segure KEY2 por cerca de 1 segundo.

### Assembler

```
python montador.py rom.asm
```

O assembler imprime a listagem (endereço, bytes, fonte) e as linhas de Verilog
para colar na função `programa` de `microedu8_top.v`.

## Próximos passos

- Teste na placa DE1-SoC (pinos, velocidade do clock e filtro dos botões).
- Programa de demonstração final.
- Placa de circuito impresso (PCB), se exigida.
