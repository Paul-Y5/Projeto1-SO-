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

# Estrutura : /backup.sh [-c] dir_trabalho dir_backup

counter_erro=0 #Nenhum aumento...
counter_warnings=0
counter_copied=0
counter_deleted=0
counter_updated=0
bytes_deleted=0
bytes_copied=0

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

echo $Source_DIR

#Verifica a existência da diretoria de origem
if [[ ! -d $Source_DIR ]]; then
    echo "[Erro] --> A diretoria de origem não existe!"
    exit 1
fi

#Verifica a existência da diretoria de origem
if [[ ! -d $Backup_DIR ]]; then
    echo "mkdir $Backup_DIR"
fi

#Executar em check mode ou não
if [[ $Check_mode -eq 1 ]]; then #Exucução do progrma de acordo com o argumento -c (Apenas imprime comandos que seriam executados)
    #Iterar sobre os ficheiros para fazer o backup a partir do cp (comando copy)
    for file in "$Source_DIR"/{*,.*}; do
        if [[ -e "$Backup_DIR/$file" ]]; then
            if [[ "$file" -nt "$Backup_DIR/$file" ]]; then
                echo "WARNING: Versão do ficheiro encontrada em backup desatualizada [Subistituir]"
                counter_warnings=$((counter_warnings + 1))
                echo "rm $Backup_DIR/$file"
                bytes_deleted=$((bytes_deleted + $(wc -c < $Backup_DIR/$file)))
                counter_deleted=$((counter_deleted + 1))
                echo "cp $file $Backup_DIR"
                bytes_copied=$((bytes_copied + $(wc -c < $file)))
                counter_copied=$((counter_copied + 1))

                counter_updated=$((counter_updated + 1))
            else ### Parei aqui de dar debbug
                echo "WARNING: Backup possui versão mais recente do ficheiro $file --> [Não copiado]"
                counter_warnings=$((counter_warnings + 1))
                bytes_copied=$((bytes_copied + $(wc -c < $file)))
            fi
        else
            echo "cp $file $Backup_DIR"
            counter_copied=$((counter_copied + 1))
            bytes_copied=$((bytes_copied + $(wc -c < $file)))
        fi
    done
    echo "While backuping src: $counter_erro Errors; $counter_warnings Warnings; $counter_updated Updated; $counter_copied Copied ($bytes_copied B); $counter_deleted deleted ($bytes_deleted B)"
    exit 0 #saída com sucesso
else  #Se -c não for argumento executa comandos (modo check=0)
    if [[ ! -d $Backup_DIR ]]; then
        mkdir -p "$Backup_DIR"  #-p garante que são criados as diretorias pai caso não existam
    fi
    for file in "$Source_DIR"/{*,.*}; do
        if [[ -e "$Backup_DIR/$file" ]]; then
            if [[ "$file" -nt "$Backup_DIR/$file" ]]; then
                echo "WARNING: Versão do ficheiro encontrada em backup desatualizada [Subistituir]"
                counter_warnings=$((counter_warnings + 1))
                rm $Backup_DIR/$file

                bytes_deleted=$((bytes_deleted + $(wc -c < $Backup_DIR/$file)))
                counter_deleted=$((counter_deleted + 1))

                cp $file $Backup_DIR

                bytes_copied=$((bytes_copied + $(wc -c < $file)))
                counter_copied=$((counter_copied + 1))

                counter_updated=$((counter_updated + 1))
            else
                echo "WARNING: Backup possui versão mais recente do ficheiro $file --> [Não copiado]"
                counter_warnings=$((counter_warnings + 1))
                bytes_copied=$((bytes_copied + $(wc -c < $file)))
            fi
        else
            cp "$file" "$Backup_DIR"
            counter_copied=$((counter_copied + 1))
            bytes_copied=$((bytes_copied + $(wc -c < $file)))
            echo "[Ficheiro $file copiado para backup]"
        fi
    done
    echo "While backuping src: $counter_erro Errors; $counter_warnings Warnings; $counter_updated Updated; $counter_copied Copied ($bytes_copied B); $counter_deleted deleted ($bytes_deleted B)"
    exit 0
fi