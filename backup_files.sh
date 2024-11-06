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

#Funções Auxiliares
source ./function_log.sh

#Log file creation
##Obtém o data + horário atual
time_LOG=$(date +"%H:%M:%S")
LOG_date=$(date +"%d_%B_%Y")
log_file="Backup_files[$LOG_date"-"$time_LOG].log"
touch $log_file
echo "|Log realizado para registro de todos os acontecimentos durante o backup da diretoria de trabalho |\n" >> $log_file
echo "---------------------------------------------------------------------------------------------------\n" >> $log_file

remove_files_NE() {
    #Remover ficheiros da diretoria backup que não existem na diretoria de origem
    local source_dir="$1"
    local backup_dir="$2"

    for backup_file in "$backup_dir"/{*,.*}; do
        #Ignorar se for '.' ou '..'
        if [[ "$backup_file" == "$backup_dir/." || "$backup_file" == "$backup_dir/.." || "$backup_file" == "$backup_dir/.*" || "$backup_file" == "$backup_dir/*" ]]; then
            continue
        fi

        #Nome base do ficheiro em backup
        local basename="${backup_file##*/}"
        local source_file="$source_dir/$basename"

        #Verificar se o arquivo correspondente não existe na diretoria de origem
        if [[ ! -e "$source_file" ]]; then
            echo "A remover $backup_file [não existe em $source_dir]"
            rm "$backup_file" || { echo "[ERRO] ao remover $backup_file"; } #Remover ficheiro
            log $log_file "rm "$backup_file""
        fi
    done

    return 0
}

#Verificações iniciais
if [[ $# -lt 2 || $# -gt 3 ]]; then #Condição de intervalo de quantidade de argumentos [2 a 3]
    echo "[Erro] --> Número de argumentos inválido!"
    exit 1 #saída com erro
fi

#Utilização de variáveis para verificar se foi passado o argumento -c para ativar Check mode
Check_mode=0

#Opções de argumentos
while getopts "c" opt; do
    case $opt in
        c) Check_mode=1 ;;
        \?) echo "[Erro] --> Opção inválida: -$OPTARG"; exit 1 ;;
        :) echo "[Erro] --> A opção -$OPTARG requer um argumento."; exit 1 ;;
    esac
done

shift $((OPTIND - 1)) #Remover argumentos que já foram guardados em variáveis

#Variáveis para os argumentos com o path de source e backup
Source_DIR=$1
Backup_DIR=$2

#Verifica a existência da diretoria de origem
if ! [[ -d $Source_DIR ]]; then
    echo "[Erro] --> A diretoria de origem não existe!"
    exit 1
else
    #Verifica à partida se os ficheiros na diretoria backup existem na source se não remove-os
    remove_files_NE $Source_DIR $Backup_DIR
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

                echo "rm  $Backup_DIR/$filename"
                
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
                log $log_file "Warning substituído"

                rm  "$Backup_DIR/$filename"
                log $log_file "rm "$Backup_DIR/$filename""

                cp -a $file $Backup_DIR
                log $log_file "cp -a $file $Backup_DIR"

                echo "$filename substituído"
            else
                echo "WARNING: Backup possui versão mais recente do ficheiro $file --> [Não substituído]"
                log $log_file "Warning não substituído"
            fi
        else
            cp -a "$file" "$Backup_DIR"
            log "$log_file" "cp -a $file $Backup_DIR"

            echo $log_file "[Ficheiro $file copiado para backup]"
        fi
    done
    exit 0
fi