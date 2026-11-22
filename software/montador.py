#!/usr/bin/env python3
# ==============================================================
# montador.py  -  Assembler da MicroEdu-8
# Le um programa em assembly (.asm) e gera:
#   1) o trecho de Verilog para colar na funcao "programa" da CPU
#   2) a listagem (endereco, bytes, linha original)
#
# Uso:   python montador.py programa.asm
#        python montador.py programa.asm -o saida.txt
#
# Sintaxe:
#   ; comentario
#   rotulo:  INSTRUCAO  operando     (rotulo e operando sao opcionais)
#   NOME = valor                     (define uma constante)
# Numeros: decimal (10), hexadecimal (0x0A ou $0A) ou binario (0b1010)
# ==============================================================
import sys

# mnemonico -> (opcode, tipo de operando)   tipo: "n" = tem operando, "-" = nao tem
INSTRUCOES = {
    "HLT":  (0x0, "-"),
    "LDI":  (0x1, "n"),
    "ADDI": (0x2, "n"),
    "SUBI": (0x3, "n"),
    "LDA":  (0x4, "n"),
    "STA":  (0x5, "n"),
    "ADD":  (0x6, "n"),
    "SUB":  (0x7, "n"),
    "JMP":  (0x8, "n"),
    "JZ":   (0x9, "n"),
    "JNZ":  (0xA, "n"),
    "IN":   (0xB, "-"),
    "OUT":  (0xC, "-"),
}
TAMANHO_ROM = 0x80   # enderecos 00-7F sao a ROM de programa


class ErroAsm(Exception):
    pass


def numero(texto, simbolos, num_linha):
    """Converte um texto em numero: constante, rotulo, decimal, 0x.., $.., 0b.."""
    t = texto.strip()
    if t in simbolos:
        return simbolos[t]
    try:
        if t.startswith("$"):
            return int(t[1:], 16)
        return int(t, 0)          # entende 0x.. e 0b..; decimal comum tambem
    except ValueError:
        raise ErroAsm(f"linha {num_linha}: '{t}' nao e numero nem nome conhecido")


def separar(linha):
    """Tira comentario e separa  rotulo / mnemonico / operando."""
    linha = linha.split(";")[0].strip()
    rotulo = None
    if ":" in linha:
        rotulo, linha = linha.split(":", 1)
        rotulo = rotulo.strip()
        linha = linha.strip()
    return rotulo, linha


def montar(texto):
    linhas = texto.splitlines()
    simbolos = {}
    # ---------- passada 1: descobre o endereco de cada rotulo ----------
    pc = 0
    for num, bruta in enumerate(linhas, start=1):
        rotulo, resto = separar(bruta)
        if rotulo:
            if rotulo in simbolos:
                raise ErroAsm(f"linha {num}: rotulo '{rotulo}' repetido")
            if rotulo.upper() in INSTRUCOES:
                raise ErroAsm(f"linha {num}: '{rotulo}' e nome de instrucao, escolha outro nome")
            simbolos[rotulo] = pc
        if not resto:
            continue
        if "=" in resto:                                   # constante:  NOME = valor
            nome, valor = resto.split("=", 1)
            nome = nome.strip()
            if not nome.isidentifier():
                raise ErroAsm(f"linha {num}: nome de constante invalido '{nome}'")
            simbolos[nome] = numero(valor, simbolos, num)
            continue
        mnem = resto.split()[0].upper()
        if mnem not in INSTRUCOES:
            raise ErroAsm(f"linha {num}: instrucao desconhecida '{mnem}'")
        pc += 2
    if pc > TAMANHO_ROM:
        raise ErroAsm(f"programa com {pc} bytes; a ROM so tem {TAMANHO_ROM} (enderecos 00-7F)")

    # ---------- passada 2: gera os bytes ----------
    saida = []     # lista de (endereco, byte_opcode, byte_operando, texto_original)
    pc = 0
    for num, bruta in enumerate(linhas, start=1):
        rotulo, resto = separar(bruta)
        if not resto or "=" in resto:
            continue
        partes = resto.split(None, 1)
        mnem = partes[0].upper()
        opcode, tipo = INSTRUCOES[mnem]
        if tipo == "-":
            if len(partes) > 1:
                raise ErroAsm(f"linha {num}: {mnem} nao tem operando")
            operando = 0
        else:
            if len(partes) < 2:
                raise ErroAsm(f"linha {num}: {mnem} precisa de um operando")
            operando = numero(partes[1], simbolos, num)
            if not 0 <= operando <= 255:
                raise ErroAsm(f"linha {num}: operando {operando} fora de 0..255")
        original = (rotulo + ": " if rotulo else "") + resto
        saida.append((pc, opcode, operando, original))
        pc += 2
    return saida, simbolos


def formatar(saida):
    verilog = ["            // ---- gerado por montador.py ----"]
    for end, op, opr, original in saida:
        verilog.append(
            f"                8'h{end:02X}: programa = 8'h{op:02X};  "
            f"8'h{end+1:02X}: programa = 8'h{opr:02X};   // {original}")
    listagem = ["End  Bytes  Fonte"]
    for end, op, opr, original in saida:
        listagem.append(f"{end:02X}   {op:02X} {opr:02X}  {original}")
    return "\n".join(verilog), "\n".join(listagem)


def main():
    args = sys.argv[1:]
    if not args or args[0] in ("-h", "--help"):
        print("Uso: python montador.py programa.asm [-o saida.txt]")
        return 0
    caminho = args[0]
    destino = args[args.index("-o") + 1] if "-o" in args else None
    try:
        with open(caminho, encoding="utf-8") as f:
            texto = f.read()
        saida, _ = montar(texto)
    except FileNotFoundError:
        print(f"Erro: arquivo '{caminho}' nao encontrado")
        return 1
    except ErroAsm as e:
        print("Erro:", e)
        return 1
    verilog, listagem = formatar(saida)
    resultado = ("=== LISTAGEM ===\n" + listagem +
                 "\n\n=== COLE NA FUNCAO 'programa' DO VERILOG (dentro do case, antes do default) ===\n" +
                 verilog + "\n")
    if destino:
        with open(destino, "w", encoding="utf-8") as f:
            f.write(resultado)
        print(f"Pronto: {len(saida)} instrucoes, {2*len(saida)} bytes. Resultado em {destino}")
    else:
        print(resultado)
    return 0


if __name__ == "__main__":
    sys.exit(main())
