# MicroEdu-8

Computador educacional de 8 bits, construído do zero em Verilog para a placa
**DE1-SoC** (Cyclone V 5CSEMA5F31C6), com **bootloader** próprio, **mini sistema
operacional com menu** e **assembler** em Python.

Projeto Garagem: "do bit ao jogo" — Pós-graduação em Computação Aplicada,
IFSP Guarulhos. Autora: Giselle Creuza Silva.

## Estado atual

| Parte | Situação |
|---|---|
| CPU (microcódigo, 17 instruções) | pronta, testada em simulação e na placa |
| Bootloader (ROM) | pronto, testado em simulação e na placa |
| Sistema com menu: soma e subtração | pronto, testado em simulação e na placa |
| Assembler (`montador.py`) | pronto |
| Teste na placa DE1-SoC | feito: boot, menu, soma, subtração, reset |
| Mudança ao vivo de uma linha de código | testada (menu F0 → C0) |
| Programa de demonstração | calculadora (soma e subtração), funcionando |
| Artigo e defesa | em andamento |

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
   resultado. ENTER volta ao menu. Na subtração, um resultado negativo aparece
   em complemento de dois (3 − 5 = `FE`).

A rotina `le_numero` (espera ENTER e lê as chaves) é usada pelo menu e pela
calculadora, e faz o papel de uma "chamada de sistema".

O boot leva cerca de 11 segundos na placa, com SW9 e SW8 ligadas.

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

Para o uso normal, **SW9 e SW8 ficam sempre ligadas**.

## Esquemático (diagrama de blocos)

Como o projeto usa somente os elementos da própria DE1-SoC (sem placa de
circuito impresso própria), o esquemático é a ligação entre esses elementos e a
máquina dentro do FPGA:

```
 ENTRADAS (DE1-SoC)                FPGA                SAÍDAS (DE1-SoC)

 CLOCK_50 ------------>+---------------------------+--> HEX3:HEX2  (OUT)
 KEY0 (passo)  ------->|        MicroEdu-8         |--> HEX1:HEX0  (A)
 KEY1 (reset)  ------->|                           |--> LEDR0-7    (A em bin.)
 KEY2 (ENTER)  ------->|  CPU + ROM + RAM          |--> LEDR8      (HLT)
 SW0-SW7 (dados) ----->|  bootloader + menu        |--> LEDR9      (passo)
 SW8, SW9 (velocidade)>+---------------------------+
```

Os pinos usados estão em `hdl/pinos_de1soc.qsf` (53 sinais, padrão 3,3 V LVTTL).
Principais:

| Sinal | Pino |
|---|---|
| CLOCK_50 | AF14 |
| KEY0, KEY1, KEY2 | AA14, AA15, W15 |
| SW0–SW9 | AB12, AC12, AF9, AF10, AD11, AD12, AE11, AC9, AD10, AE12 |
| LEDR0–LEDR9 | V16, W16, V17, V18, W17, W19, Y19, W20, W21, Y21 |

Os pinos dos displays HEX0 a HEX3 estão no arquivo `.qsf`.

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
hdl/microedu8_top.v      CPU + topo para a placa (Verilog)
hdl/pinos_de1soc.qsf     pinos da DE1-SoC para o Quartus
software/montador.py     assembler (Python 3)
software/rom.asm         bootloader + sistema com menu
software/dobro.asm       exemplo simples
```

## Como usar

### Na placa DE1-SoC (Quartus Prime Lite 20.1)

1. Crie um projeto novo (**File → New Project Wizard**), com o dispositivo
   `5CSEMA5F31C6` e o top-level `microedu8_top`. Adicione `hdl/microedu8_top.v`.
2. Importe os pinos: **Assignments → Import Assignments** e escolha
   `hdl/pinos_de1soc.qsf`.
3. Compile (**Processing → Start Compilation**). Os avisos de temporização
   (falta do arquivo `.sdc`) são esperados.
4. Grave na placa: **Tools → Programmer**, escolha o hardware `DE-SoC [USB-1]`,
   selecione `output_files/microedu8_top.sof` no chip `5CSEMA5` e clique em
   **Start**.
5. Ligue SW9 e SW8 (execução automática rápida) e dê reset (KEY1).
6. Espere `b0` virar `F0` (o boot copia o sistema para a RAM).
7. Ponha o número da opção nas chaves e aperte KEY2.

O FPGA perde o projeto quando a placa perde energia, então é preciso gravar o
`.sof` de novo a cada vez que ela é ligada.

Uso de recursos na compilação: cerca de 755 ALMs (2%), 1187 registradores e
53 pinos.

### Simulador

1. Carregue `hdl/microedu8_top.v` no simulador.
2. Ligue SW9 e SW8 e dê reset (KEY1).
3. Espere `b0` virar `F0`.
4. Ponha o número da opção nas chaves e aperte KEY2.

Observação: no simulador, segure KEY2 por cerca de 1 segundo.

### Assembler

```
python montador.py rom.asm
```

O assembler imprime a listagem (endereço, bytes, fonte) e as linhas de Verilog
para colar na função `programa` de `microedu8_top.v`.

## Decisões de projeto

- **Sem placa de circuito impresso (PCB) própria.** Por orientação do professor,
  o projeto usa os elementos da própria placa FPGA, e o esquemático é feito com
  eles (seção "Esquemático").
- **Menu em vez de monitor de memória.** O sistema é um menu com a calculadora
  e uma rotina de leitura que faz o papel de chamada de sistema.
- **Saída nos displays de 7 segmentos**, sem terminal serial.

## Próximos passos

- Artigo (resumo expandido) e preparação da defesa.
- Ensaio da demonstração na Mostra Garagem.
- Se sobrar tempo: um programa extra de demonstração.
