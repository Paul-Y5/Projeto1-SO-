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
            rm "$backup_file" || { echo "[ERRO] ao remover $backup_file"; } #Remover ficheiro
            log $log_file "rm "$backup_file""
            echo "$backup_file removido [não existe em $source_dir]"
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
        c) Check_mode=1 ;; #Ativar Check mode
        *) echo "[Erro] --> Argumento inválido!"; exit 1 ;; #Argumento inválido
    esac
done

shift $((OPTIND - 1)) #Remover argumentos que já foram guardados em variáveis

#Variáveis para os argumentos com o path de source e backup
Source_DIR=$1 #Diretoria de origem
Backup_DIR=$2 #Diretoria de backup

if [[ $Check_mode -eq 0 ]]; then #Se check mode ativo não irá fazer log
    #Log file
    ##Obtém o data + horário atual
    time_LOG=$(date +"%H:%M:%S")
    LOG_date=$(date +"%d_%B_%Y")
    log_file="Backup[$LOG_date"-"$time_LOG].log"
    touch $log_file

    echo "|Log backup da diretoria $Source_DIR |" >> $log_file
    echo "---------------------------------------------------------------------------------------------------" >> $log_file
fi

#Verifica a existência da diretoria de origem
if ! [[ -d $Source_DIR ]]; then
    echo "[Erro] --> A diretoria de origem não existe!"
    exit 1
else
    #Verifica à partida se os ficheiros na diretoria backup existem na source se não remove-os
    remove_files_NE $Source_DIR $Backup_DIR
fi

if ! [[ -e $Backup_DIR ]]; then
    if [[ $Check_mode -eq 1 ]]; then
        echo "mkdir -p $Backup_DIR"
        mkdir -p "$Backup_DIR" || { echo "[Erro] ao criar diretoria bakcup"; exit 1; }
    else
        mkdir -p "$Backup_DIR" || { echo "[Erro] ao criar diretoria bakcup"; exit 1; }
        echo ${log_file%.*} "diretoria $Backup_DIR criada com sucesso!"
        log $log_file "mkdir -p "$Backup_DIR""
    fi
fi

#Parte principal do script
#Iterar sobre os ficheiros para fazer o backup a partir do cp -a (comando copy)
for file in "$Source_DIR"/{*,.*}; do
    if [[ -d $file ]]; then #Ignorar diretórios
        continue
    fi

    filename="${file##*/}"
    current_backup_DIR="$Backup_DIR/$filename"

    if [[ -e "$current_backup_DIR" ]]; then
        if [[ "$file" -nt "$current_backup_DIR" ]]; then
            if [[ $Check_mode -eq 1 ]]; then #Exucução do programa de acordo com o argumento -c (Apenas imprime comandos que seriam executados)
                echo "WARNING: Versão do ficheiro $file encontrada em backup desatualizada [Atualizar]"

                echo "rm  $Backup_DIR/$filename" 
                
                echo "cp -a $file $Backup_DIR"
            else
                echo "WARNING: Versão do ficheiro $file encontrada em backup desatualizada [Atualizar]"
                log $log_file "Warning $current_backup_DIR [substituído]"

                rm  "$Backup_DIR/$filename" || { echo "[ERRO] ao remover $Backup_DIR/$filename"; continue; } #Remover ficheiro
                log $log_file "rm "$Backup_DIR/$filename"" #Registo do log

                cp -a $file $Backup_DIR || { echo "[ERRO] ao copiar $file para $Backup_DIR"; continue; } #Cópia do ficheiro
                log $log_file "cp -a $file $Backup_DIR"

                echo ${log_file} ""$filename" substituído"
            fi
        else
            echo "WARNING: "${Backup_DIR##*/}" possui versão mais recente do ficheiro $file --> [Não copiado]" #Mensagem de aviso
            log $log_file "WARNING: "${Backup_DIR##*/}" possui versão mais recente do ficheiro $file --> [Não copiado]"
        fi
    else
        if [[ $Check_mode -eq 1 ]]; then
            echo "cp -a $file $Backup_DIR"
        else
            cp -a "$file" "$Backup_DIR" || { echo "[ERRO] ao copiar $file para $Backup_DIR"; continue; } #Cópia do ficheiro
            log "$log_file" "cp -a $file $Backup_DIR"

            echo ${log_file%.*} "[Ficheiro $file copiado para $Backup_DIR]" #Mensagem a confirmar"
        fi
    fi
done
exit 0 #saída com sucesso