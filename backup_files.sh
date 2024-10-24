#!/bin/bash

# Considera que a diretoria de trabalho (fonte)
# apenas tem ficheiros não tendo qualquer sub-diretoria.

# Este script permite a utilização de
# -c como parâmetro, mas não as restantes opções

# Deve atualizar apenas os ficheiros com
# data de modificação posterior à do ficheiro correspondente no backup.

# Print no terminal de todas as execuções de comandos cp -a -a, rm, etc.

# Minimo de argumentos: 2 (diretoria de origem) e (diretoria de destino);
# Max args = min args + [-c] -->  ativar a opção de checking (não executa comandos apendas dá print);

# $1 é a diretoria origem e $2 a diretoria destino (backup)

# Estrutura : /backup.sh [-c] dir_trabalho dir_backup

if [[ $# -lt 2 || $# -gt 3 ]]; then #Condição de intervalo de quantidade de argumentos [2 a 3]
    echo "[Erro] --> Número de argumentos inválido!"
    exit 1 #saída com erro
fi

if [[ $# -eq 3 && $1 -ne "-c" ]]; then #Condição de uso do -c
    echo "[Erro] --> Argumento 3 ($1) impossível | Argumentos possíveis: -c"
    exit 1
fi

#Utilização de variáveis para as diretorias para verificar se foi passado o argumento -c para ativar Check mode
if [[ $# -eq 2 ]]; then
    Check_mode=0
    Source_DIR=$1
    Backup_DIR=$2
else
    Check_mode=1
    Source_DIR=$2
    Backup_DIR=$3
fi

#Verifica a existência da diretoria de origem
if [[ ! -d $Source_DIR ]]; then
    echo "[Erro] --> A diretoria de origem não existe!"
    exit 1
fi

#Verifica a existência da diretoria de origem
if [[ ! -d $Backup_DIR  && $Check_mode -eq 1 ]]; then
    echo "mkdir $Backup_DIR"
elif [[ ! -d $Backup_DIR && $Check_mode -eq 0 ]]; then
    mkdir "$Backup_DIR"
fi

#Executar em check mode ou não
if [[ $Check_mode -eq 1 ]]; then #Exucução do programa de acordo com o argumento -c (Apenas imprime comandos que seriam executados)
    #Iterar sobre os ficheiros para fazer o backup a partir do cp -a (comando copy)
    for file in "$Source_DIR"/{*,.*}; do
        if [[ -d $file ]]; then
            continue
        fi
        filename="${file##*/}"
        if [[ -e "$Backup_DIR/$filename" ]]; then
            if [[ "$file" -nt "$Backup_DIR/$filename" ]]; then
                echo "WARNING: Versão do ficheiro encontrada em backup desatualizada [Subistituir]"

                echo "rm  "$Backup_DIR/$filename""
                
                echo "cp -a $file $Backup_DIR"
            else
                echo "WARNING: Backup possui versão mais recente do ficheiro $file --> [Não copiado]"
            fi
        else
            echo "cp -a $file $Backup_DIR"
        fi
    done
    exit 0 #saída com sucesso
else  #Se -c não for argumento executa comandos (modo check=0)
    for file in "$Source_DIR"/{*,.*}; do
        filename="${file##*/}"
        if [[ -e "$Backup_DIR/$filename" ]]; then
            if [[ "$file" -nt "$Backup_DIR/$filename" ]]; then
                echo "WARNING: Versão do ficheiro encontrada em backup desatualizada [Subistituir]"

                rm  "$Backup_DIR/$filename"

                cp -a $file $Backup_DIR
            else
                echo "WARNING: Backup possui versão mais recente do ficheiro $file --> [Não copiado]"
            fi
        else
            cp -a "$file" "$Backup_DIR"
            echo "[Ficheiro $file copiado para backup]"
        fi
    done
    exit 0
fi