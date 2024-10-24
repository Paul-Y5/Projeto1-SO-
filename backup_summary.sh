#!/bin/bash

# Variáveis de contagem globais
counter_erro=0
counter_warnings=0
counter_copied=0
counter_deleted=0
counter_updated=0
bytes_deleted=0
bytes_copied=0

if [[ $# -lt 2 || $# -gt 5 ]]; then
    echo "[Erro] --> Número de argumentos inválido!"
    exit 1
fi

# Utilização de variáveis para argumentos
Check_mode=0
tfile=""
regexpr=""

# Opções de argumentos
while getopts "cb:r:" opt; do
    case $opt in
        c) Check_mode=1 ;;
        b) tfile="$OPTARG" ;;
        r) regexpr="$OPTARG" ;;
        \?) echo "[Erro] --> Opção inválida: -$OPTARG"; exit 1 ;;
        :) echo "[Erro] --> A opção -$OPTARG requer um argumento."; exit 1 ;;
    esac
done

shift $((OPTIND - 1)) #Remover argumentos que já foram guardadosem variáveis
Source_DIR=$1
Backup_DIR=$2

# Verifica a existência da diretoria de origem
if [[ ! -d $Source_DIR ]]; then
    echo "[Erro] --> A diretoria de origem não existe!"
    exit 1
fi

if [[ ! -d $Backup_DIR && $Check_mode -eq 1 ]]; then
    echo "mkdir $Backup_DIR"
    mkdir "$Backup_DIR"   
elif [[ ! -d $Backup_DIR && $Check_mode -eq 0 ]]; then
    mkdir "$Backup_DIR"
fi

ignore_files() {
    file_ig="$1"
    basename="${file_ig##*/}"
    if [[ -n "$tfile" && -f "$tfile" ]]; then
        if grep -qx "$basename" "$tfile"; then
            return 0
        fi
    fi
    return 1
}

backup() {
    local source_dir="$1"
    local backup_dir="$2"

    for file in "$source_dir"/{*,.*}; do
    
        # Variáveis para contadores internos
        counter_erro_i=0
        counter_warnings_i=0
        counter_copied_i=0
        counter_deleted_i=0
        counter_updated_i=0
        bytes_deleted_i=0
        bytes_copied_i=0

        if ignore_files "$file"; then
            continue #ignorar ficheiros com o nome encontrado no ficheiro
        fi

        if [[ -n $regexpr ]] && ! [[ "$file" =~ $regexpr ]]; then
            continue #ignorar ficheiros que não respeitam a expressão regex
        fi

        filename="${file##*/}"
        current_backup_DIR="$backup_dir/$filename"

        if [[ -f $file ]]; then 
            if [[ $Check_mode -eq 1 ]]; then  # Modo de verificação
                if [[ -e "$current_backup_DIR" ]]; then
                    if [[ "$file" -nt "$current_backup_DIR" ]]; then
                        echo "WARNING: Versão do ficheiro encontrada em backup desatualizada [Substituir]"
                        counter_warnings_i=$((counter_warnings_i + 1))

                        bytes_deleted_i=$((bytes_deleted_i + $(wc -c < "$current_backup_DIR")))
                        echo "rm $current_backup_DIR"
                        counter_deleted_i=$((counter_deleted_i + 1))
                        
                        echo "cp -a $file $backup_dir"
                        bytes_copied_i=$((bytes_copied_i + $(wc -c < "$file")))
                        counter_copied_i=$((counter_copied_i + 1))

                        counter_updated_i=$((counter_updated_i + 1))
                    else
                        echo "WARNING: Backup possui versão mais recente do ficheiro $file --> [Não copiado]"
                        counter_warnings_i=$((counter_warnings_i + 1))
                    fi
                else
                    echo "cp -a $file $backup_dIR"
                    counter_copied_i=$((counter_copied_i + 1))
                    bytes_copied_i=$((bytes_copied_i + $(wc -c < "$file")))
                fi
            else
                if [[ -e "$current_backup_DIR" ]]; then
                    if [[ "$file" -nt "$current_backup_DIR" ]]; then
                        echo "WARNING: Versão do ficheiro encontrada em backup desatualizada [Substituir]"
                        counter_warnings_i=$((counter_warnings_i + 1))

                        bytes_deleted_i=$((bytes_deleted_i + $(wc -c < "$current_backup_DIR")))
                        rm "$current_backup_DIR"
                        counter_deleted_i=$((counter_deleted_i + 1))

                        cp -a "$file" "$backup_dir"
                        bytes_copied_i=$((bytes_copied_i + $(wc -c < "$file")))
                        counter_copied_i=$((counter_copied_i + 1))

                        counter_updated_i=$((counter_updated_i + 1))
                    else
                        echo "WARNING: Backup possui versão mais recente do ficheiro $file --> [Não copiado]"
                        counter_warnings_i=$((counter_warnings_i + 1))
                    fi
                else
                    echo "[Ficheiro $file copiado para backup]"
                    cp -a "$file" "$backup_dir"
                    counter_copied_i=$((counter_copied_i + 1))
                    bytes_copied_i=$((bytes_copied_i + $(wc -c < "$file")))
                fi
            fi
        fi

        # Atualiza os contadores globais
        counter_erro=$((counter_erro + counter_erro_i))
        counter_warnings=$((counter_warnings + counter_warnings_i))
        counter_updated=$((counter_updated + counter_updated_i))
        counter_copied=$((counter_copied + counter_copied_i))
        counter_deleted=$((counter_deleted + counter_deleted_i))
        bytes_deleted=$((bytes_deleted + bytes_deleted_i))
        bytes_copied=$((bytes_copied + bytes_copied_i))
        echo $counter_copied
        echo $counter_copied_i
    done

    # Imprime o status após processar arquivos
    echo "While backuping files de $Source_DIR: $counter_erro_i Errors; $counter_warnings_i Warnings; $counter_updated_i Updated; $counter_copied_i Copied ($bytes_copied_i B); $counter_deleted_i Deleted ($bytes_deleted_i B)"
    echo "-------------------------------------------------"

    for dir in "$source_dir"/{*.,*}; do
        if [[ -d $dir ]]; then
            echo "estive aqui"
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
}

backup "$Source_DIR" "$Backup_DIR"

# Mensagem final com o resumo
echo "Backuping Summary: $counter_erro Errors; $counter_warnings Warnings; $counter_updated Updated; $counter_copied Copied ($bytes_copied B); $counter_deleted Deleted ($bytes_deleted B)"
echo "-------------------------------------------------"

exit 0