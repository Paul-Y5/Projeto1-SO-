#!/bin/bash

# Considera que a diretoria de trabalho (fonte)
# apenas tem ficheiros não tendo qualquer sub-diretoria.

# Este script permite a utilização de
# -c como parâmetro, mas não as restantes opções

# Deve atualizar apenas os ficheiros com
# data de modificação posterior à do ficheiro correspondente no backup.

# Print no terminal de todas as execuções de comandos cp -a, rm, etc.

# Minimo de argumentos: 2 (diretoria de origem) e (diretoria de destino);
# Max args = min args + [-c] -->  ativar a opção de checking (não executa comandos apendas dá print);

# $1 é a diretoria origem e $2 a diretoria destino (backup)

if [[ $# < 2 || $# == 3 && $3 != "-c" ]]; then #Condição de intervalo de quantidade de argumentos [2 a 3]
    echo "Erro nos argumentos!"
else
    echo "resulta $@"
    if [[ -d $1 && -d $2 ]]; then
        if [[ $# == 3 ]]; then
            echo "print comandos que seriam executados"
        else
            for file in $1; do

            done
        fi
    else
        echo "Resulta não são dir"
    fi
fi