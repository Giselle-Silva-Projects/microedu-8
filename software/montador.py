#!/usr/bin/env python3
# ==============================================================
# montador.py  -  Assembler da MicroEdu-8
# Le um programa em assembly (.asm) e gera:
#   1) a listagem (endereco, bytes, linha original)
#   2) o trecho de Verilog para colar na funcao "programa" da CPU
#
# Uso:   python montador.py programa.asm
#        python montador.py programa.asm -o saida.txt
#
# Sintaxe:
#   ; comentario
#   rotulo:  INSTRUCAO  operando     (rotulo e operando sao opcionais)
#   NOME = valor                     (define uma constante)
# Numeros: decimal (10), hexadecimal (0x0A ou $0A) ou binario (0b1010)
# Contas simples com + e -:   fim - inicio     ou     tabela + 1
# Diretivas:
#   .org ENDERECO         o codigo seguinte comeca neste endereco
#   .byte v1, v2, ...     coloca bytes de dados soltos
#   .guardar_em ENDERECO  os bytes seguintes sao gravados (na ROM) a partir
#                         deste endereco, mas os rotulos continuam valendo
#                         para o endereco onde o codigo VAI RODAR (na RAM)
# ==============================================================
import re
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
    "LDN":  (0xD, "n"),
    "STN":  (0xE, "n"),
}
DIRETIVAS = (".org", ".byte", ".guardar_em")
TAMANHO_ROM = 0x80   # enderecos 00-7F sao a ROM de programa


class ErroAsm(Exception):
    pass


def termo(texto, simbolos, num_linha):
    """Converte um termo simples: constante, rotulo, decimal, 0x.., $.., 0b.."""
    t = texto.strip()
    if t == "":
        raise ErroAsm(f"linha {num_linha}: valor faltando")
    if t in simbolos:
        return simbolos[t]
    try:
        if t.startswith("$"):
            return int(t[1:], 16)
        return int(t, 0)          # entende 0x.. e 0b..; decimal comum tambem
    except ValueError:
        raise ErroAsm(f"linha {num_linha}: '{t}' nao e numero nem nome conhecido")


def numero(texto, simbolos, num_linha):
    """Avalia um valor, aceitando contas com + e -  (ex.: fim - inicio)."""
    pedacos = re.split(r"([+-])", texto.strip())
    total = termo(pedacos[0], simbolos, num_linha)
    for i in range(1, len(pedacos), 2):
        valor = termo(pedacos[i + 1], simbolos, num_linha)
        total = total + valor if pedacos[i] == "+" else total - valor
    return total


def separar(linha):
    """Tira comentario e separa  rotulo / resto."""
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
                raise ErroAsm(f"linha {num}: '{rotulo}' e nome de instrucao")
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
        mnem = resto.split()[0]
        if mnem.lower() in DIRETIVAS:
            args = resto[len(mnem):].strip()
            d = mnem.lower()
            if d == ".org":
                pc = numero(args, simbolos, num)
            elif d == ".byte":
                pc += len([x for x in args.split(",") if x.strip() != ""])
            continue                          # .guardar_em nao muda o pc
        if mnem.upper() not in INSTRUCOES:
            raise ErroAsm(f"linha {num}: instrucao desconhecida '{mnem}'")
        pc += 2

    # ---------- passada 2: gera os bytes ----------
    # cada item: (endereco_onde_roda, endereco_onde_grava, [bytes], texto_original)
    saida = []
    ocupado = {}
    pc = 0
    delta = 0                  # endereco de gravacao = pc + delta
    for num, bruta in enumerate(linhas, start=1):
        rotulo, resto = separar(bruta)
        if not resto or "=" in resto:
            continue
        original = (rotulo + ": " if rotulo else "") + resto
        mnem = resto.split()[0]
        dados = None
        if mnem.lower() in DIRETIVAS:
            args = resto[len(mnem):].strip()
            d = mnem.lower()
            if d == ".org":
                pc = numero(args, simbolos, num)
                delta = 0
                continue
            if d == ".guardar_em":
                delta = numero(args, simbolos, num) - pc
                continue
            itens = [x for x in args.split(",") if x.strip() != ""]
            dados = [numero(x, simbolos, num) for x in itens]
            for v in dados:
                if not 0 <= v <= 255:
                    raise ErroAsm(f"linha {num}: valor {v} fora de 0..255")
        else:
            partes = resto.split(None, 1)
            mn = partes[0].upper()
            opcode, tipo = INSTRUCOES[mn]
            if tipo == "-":
                if len(partes) > 1:
                    raise ErroAsm(f"linha {num}: {mn} nao tem operando")
                operando = 0
            else:
                if len(partes) < 2:
                    raise ErroAsm(f"linha {num}: {mn} precisa de um operando")
                operando = numero(partes[1], simbolos, num)
                if not 0 <= operando <= 255:
                    raise ErroAsm(f"linha {num}: operando {operando} fora de 0..255")
            dados = [opcode, operando]
        grava = pc + delta
        for k in range(len(dados)):
            end_ = grava + k
            if not 0 <= end_ < TAMANHO_ROM:
                raise ErroAsm(f"linha {num}: endereco {end_:02X} fora da ROM")
            if end_ in ocupado:
                raise ErroAsm(f"linha {num}: endereco {end_:02X} ja usado")
            ocupado[end_] = num
        saida.append((pc, grava, dados, original))
        pc += len(dados)
    return saida, simbolos


def formatar(saida):
    verilog = ["            // ---- gerado por montador.py ----"]
    for roda, grava, dados, original in sorted(saida, key=lambda x: x[1]):
        for ini in range(0, len(dados), 4):          # ate 4 bytes por linha
            pedaco = dados[ini:ini + 4]
            celulas = "  ".join(f"8'h{grava + ini + k:02X}: programa = 8'h{b:02X};"
                                for k, b in enumerate(pedaco))
            comentario = f"   // {original}" if ini == 0 else ""
            verilog.append("                " + celulas + comentario)
    listagem = ["Roda  Grava  Bytes        Fonte"]
    for roda, grava, dados, original in saida:
        bytes_txt = " ".join(f"{b:02X}" for b in dados)
        listagem.append(f"{roda:02X}    {grava:02X}     {bytes_txt:<11}  {original}")
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
    total = sum(len(d) for _, _, d, _ in saida)
    titulo = "=== COLE NA FUNCAO 'programa' DO VERILOG (antes do default) ==="
    resultado = ("=== LISTAGEM ===\n" + listagem + "\n\n" +
                 titulo + "\n" + verilog + "\n")
    if destino:
        with open(destino, "w", encoding="utf-8") as f:
            f.write(resultado)
        print(f"Pronto: {total} bytes. Resultado em {destino}")
    else:
        print(resultado)
    return 0


if __name__ == "__main__":
    sys.exit(main())
