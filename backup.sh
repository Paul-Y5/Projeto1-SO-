#!/bin/bash

#Funções auxiliares:
source ./create_array.sh

ignore_files() {
    #Função auxiliar para verificar se nome de determinado
    #ficheiro se encontra no array de nomes de ficheiros a ignorar.

    #Argumentos necessários
    local file_ig="$1"
    shift
    local array_ignore="$@"

    basename="${file_ig##*/}"

    for file in "${array_ignore[@]}"; do
        if [[ "$basename" == "$file" ]]; then
            return 0 #Ficheiro ignorado
        fi
    done

    return 0 #Ficheiro não ignorado 
}

check_file() {
    local file="$1"
    local regexpr="$2"

    if [[ -n "$regexpr" && ! "$file" =~ $regexpr ]]; then
        return 1  #Arquivo não respeita regex não será copiado
    fi

    return 0 #Arquivo vai ser copiado, pois respeita regex
}

#----------------------------------------------
#Condição de argumentos
if [[ $# -lt 2 || $# -gt 5 ]]; then
    echo "[Erro] --> Número de argumentos inválido!"
    exit 1
fi

#Utilização de variáveis para argumentos
Check_mode=0
tfile=""
regexpr=""

#Opções de argumentos
while getopts "cb:r:" opt; do
    case $opt in
        c) Check_mode=1 ;;
        b) tfile="$OPTARG" ;;
        r) regexpr="$OPTARG" ;;
        \?) echo "[Erro] --> Opção inválida: -$OPTARG"; exit 1 ;;
        :) echo "[Erro] --> A opção -$OPTARG requer um argumento."; exit 1 ;;
    esac
done

if [[ "$tfile" ]]; then
    array_ignore=($(create_array "$tfile"))
else
    echo "[WARNING] --> Sem ficheiro atribuido!" && (($counter_warnings++))
fi

shift $((OPTIND - 1)) #Remover argumentos que já foram guardados em variáveis
#Facilita na passagem dos argumentos de diretoria de origem e destino
Source_DIR=$1
Backup_DIR=$2

#Verificar a existência da diretoria de origem
if [[ ! -d $Source_DIR ]]; then
    echo "[Erro] --> A diretoria de origem não existe!"
    exit 1
fi

#Verificar existência da diretoria qure receberá os ficheiros (backup)
if [[ ! -d $Backup_DIR && $Check_mode -eq 1 ]]; then
    echo "mkdir $Backup_DIR"
    mkdir "$Backup_DIR"   
elif [[ ! -d $Backup_DIR && $Check_mode -eq 0 ]]; then
    mkdir "$Backup_DIR"
fi


source_dir="$1"
backup_dir="$2"

for file in "$source_dir"/{*,.*}; do

    if ignore_files "$file" "${array_ignore[@]}"; then
        continue #ignorar ficheiros com o nome encontrado no ficheiro
    fi

    if check_file "$file" "$regexpr"; then
        continue #ignorar ficheiros que não respeitam a expressão regex
    fi

    filename="${file##*/}"
    current_backup_DIR="$backup_dir/$filename"

    if [[ -f $file ]]; then 
        if [[ $Check_mode -eq 1 ]]; then  # Modo de verificação
            if [[ -e "$current_backup_DIR" ]]; then
                if [[ "$file" -nt "$current_backup_DIR" ]]; then
                    echo "[WARNING] --> Versão do ficheiro encontrada em backup desatualizada [Substituir]"

                    echo "rm $current_backup_DIR"
                    
                    echo "cp -a $file $backup_dir"
                else
                    echo "[WARNING] --> Backup possui versão mais recente do ficheiro $file --> [Não copiado]"
                fi
            else
                echo "cp -a $file $backup_dIR"
            fi
        else
            if [[ -e "$current_backup_DIR" ]]; then
                if [[ "$file" -nt "$current_backup_DIR" ]]; then
                    echo "[WARNING] --> Versão do ficheiro encontrada em backup desatualizada [Substituir]"

                    rm "$current_backup_DIR"

                    cp -a "$file" "$backup_dir"
                else
                    echo "[WARNING] --> Backup possui versão mais recente do ficheiro $file --> [Não copiado]"
                fi
            else
                echo "[Ficheiro $file copiado para backup]"
                cp -a "$file" "$backup_dir"
            fi
        fi
    fi
done

for dir in "$source_dir"/{*.,*}; do
    if [[ -d $dir ]]; then
        filename="${dir##*/}"
        current_backup_DIR="$backup_dir/$filename"

        if [[ $Check_mode -eq 1 ]]; then
            if [[ -e "$current_backup_DIR" ]]; then
                echo "mkdir -p $current_backup_DIR"
                mkdir -p "$current_backup_DIR"
                echo "Sub-Diretoria $filename criada com sucesso!"
                echo "backup -c $dir $current_backup_DIR"
                backup "$dir" "$current_backup_DIR"
            else
                mkdir -p "$current_backup_DIR"
                echo "Sub-Diretoria $filename criada com sucesso!"
                backup "$dir" "$current_backup_DIR"
            fi
        else
            if [[ -e "$current_backup_DIR" ]]; then
                backup "$dir" "$current_backup_DIR"
            else
                mkdir -p "$current_backup_DIR"
                echo "Sub-Diretoria $filename criada com sucesso!"
                backup "$dir" "$current_backup_DIR"
            fi
        fi
    fi
done

exit 0