#!/bin/bash
# Semelhante ao backup_files.sh, considerando agora que a
# diretoria de trabalho pode ter ficheiros e diretorias (que por sua vez podem ter
# subdiretorias). Este script deve considerar todas as opções da linha de comando.

# Print no terminal de todas as execuções de comandos cp -a -a, rm, etc.

# Minimo de argumentos: 2 (diretoria de origem) e (diretoria de destino);

# Max args: 2 + [-c] --> ativar a opção de checking (não executa comandos apendas dá print); 

# opção -b (permite a indicação de um ficheiro de texto
# que contém uma lista de ficheiros (ou diretorias) que não devem ser copiados
# para a diretoria de backup. 

# opção -r indica que apenas devem ser copiados os ficheiros que verificam uma expressão regular
# Exemplo:
# ./backup.sh [-c] [-b tfile] [-r regexpr] dir_trabalho dir_backup

# --> Pensar recursivamente <--


#Funções auxiliares:
remove_files_NE() {
    #Remover ficheiros ou sub-diretorias da diretoria backup que não existem na diretoria de origem

    local source_dir="$1"
    local backup_dir="$2"

    for backup_file in "$backup_dir"/{*,.*}; do
        #Ignorar se for '.' ou '..'
        if [[ "$backup_file" == "$backup_dir/." || "$backup_file" == "$backup_dir/.." ]]; then
            continue
        fi

        #Nome base do arquivo em backup
        local basename="${backup_file##*/}"
        local source_file="$source_dir/$basename"

        #Verificar se o arquivo correspondente não existe na diretoria de origem
        if [[ ! -e "$source_file" ]]; then
            echo "A remover $backup_file, pois não existe em $source_dir"
            
            bytes_deleted=$(($bytes_deleted + $(wc -c < "$backup_file")))
            if [[ -d  "$source_file" ]]; then
                rm -r "$backup_file" || { echo "Erro ao remover $backup_file"; continue;} #Remover recursivamente diretoria
            else
                rm "$backup_file" || { echo "Erro ao remover $backup_file"; continue;} #Remover ficheiro
            fi
            ((counter_deleted++))
        fi
    done

    return 0

}
source ./create_array.sh

ignore_files() {
    #Função auxiliar para verificar se nome de determinado
    #ficheiro se encontra no array de nomes de ficheiros a ignorar.

    #Argumentos necessários
    local file_ig="$1"
    shift
    local array_ignore=("$@")

    basename="${file_ig##*/}"

    for f in "${array_ignore[@]}"; do
        if [[ -f "$file_ig" ]]; then
            if [[ "$basename" == "$f" ]]; then
                return 0 #Ficheiro ignorado
            fi
        fi
    done

    return 1 #Ficheiro não ignorado 
}

check_file() {
    local file_a="$1"
    local regexpr="$2"

    local basename="${file_a##*/}"

    if [[ -n "$regexpr" && ! "$basename" =~ $regexpr ]]; then
        return 0  #Arquivo não respeita regex não será copiado
    fi

    return 1 #Arquivo vai ser copiado, pois respeita regex
}

#----------------------------------------------
#Condição de argumentos
if [[ $# -lt 2 || $# -gt 7 ]]; then
    echo "[Erro] --> Número de argumentos inválido!"
    exit 1 #saída com erro
fi

#Utilização de variáveis para argumentos
Check_mode=0
file_title=""
regexpr=""

#Opções de argumentos
while getopts "cb:r:" opt; do
    case $opt in
        c) Check_mode=1 ;;
        b) file_title="$OPTARG" ;;
        r) regexpr="$OPTARG" ;;
        \?) echo "[Erro] --> Opção inválida: -$OPTARG"; exit 1 ;;
        :) echo "[Erro] --> A opção -$OPTARG requer um argumento."; exit 1 ;;
    esac
done

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
if [[ -e $Backup_DIR ]]; then
    if [[ $Check_mode -eq 1 ]]; then
        echo "remove_files_NE $Source_DIR $Backup_DIR"
        remove_files_NE $Source_DIR $Backup_DIR
    elif [[ $Check_mode -eq 0 ]]; then
        remove_files_NE $Source_DIR $Backup_DIR
    fi
else
    if [[ $Check_mode -eq 1 ]]; then
        echo "mkdir $Backup_DIR"
        mkdir "$Backup_DIR"   
    elif [ $Check_mode -eq 0 ]]; then
        mkdir -p "$Backup_DIR"
    fi
fi


#Criação de array para nomes de ficheiros
if [[ "$file_title" ]]; then
    array_ignore=($(create_array "$file_title"))
else
    echo "[WARNING] --> Sem ficheiro atribuido!"
fi

local source_dir="$1"
local backup_dir="$2"

for file in "$source_dir"/{*,.*}; do

    #Ignorar se for '.' ou '..'
    if [[ "$backup_file" == "$backup_dir/." || "$backup_file" == "$backup_dir/.." ]]; then
        continue
    fi

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
                echo "backup -c $dir $current_backup_DIR"
                ./backup.sh "$dir" "$current_backup_DIR"
            else
                echo "mkdir -p $current_backup_DIR"
                mkdir -p "$current_backup_DIR"
                echo "Sub-Diretoria $filename criada com sucesso!"
                ./backup.sh "$dir" "$current_backup_DIR"
            fi
        else
            if [[ -e "$current_backup_DIR" ]]; then
                ./backup.sh "$dir" "$current_backup_DIR"
            else
                mkdir -p "$current_backup_DIR"
                echo "Sub-Diretoria $filename criada com sucesso!"
                ./backup.sh "$dir" "$current_backup_DIR"
            fi
        fi
    fi
done

exit 0