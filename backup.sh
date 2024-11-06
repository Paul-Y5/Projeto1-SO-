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
        if [[ "$backup_file" == "$backup_dir/." || "$backup_file" == "$backup_dir/.." || "$backup_file" == "$backup_dir/.*" || "$backup_file" == "$backup_dir/*" ]]; then
            continue
        fi

        #Nome base do ficheiro/diretoria em backup
        local basename="${backup_file##*/}"
        local source_file="$source_dir/$basename"

        #Verificar se o arquivo correspondente não existe na diretoria de origem
        if [[ ! -e "$source_file" ]]; then
            echo "A remover $backup_file [não existe em $source_dir]"
            if [[ -d  "$backup_file" ]]; then
                rm -r "$backup_file" || { echo "[ERRO] ao remover $backup_file"; } #Remover recursivamente diretoria
            else
                rm "$backup_file" || { echo "[ERRO] ao remover $backup_file"; } #Remover ficheiro
            fi
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

#-----------------------------------------------------------------
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

#Argumentos de diretoria de origem e destino
Source_DIR=$1
Backup_DIR=$2

#Verificar a existência da diretoria de origem
if [[ ! -d $Source_DIR ]]; then
    echo "[Erro] --> A diretoria de origem não existe!"
    exit 1
fi

#Verificar existência da diretoria que receberá os ficheiros (backup)
if ! [[ -e $Backup_DIR ]]; then
    if [[ $Check_mode -eq 1 ]]; then
        echo "mkdir -p $Backup_DIR"
        mkdir "$Backup_DIR" || { echo "[Erro] ao criar diretoria bakcup"; exit 1; } 
        backup "$Source_DIR" "$Backup_DIR" #Chamada inicial da função
    elif [ $Check_mode -eq 0 ]]; then
        mkdir -p "$Backup_DIR" | { echo "[Erro] ao criar diretoria bakcup"; exit 1; }  
        backup "$Source_DIR" "$Backup_DIR" #Chamada inicial da função
    fi
fi

#Criação de array para nomes de ficheiros
if [[ "$file_title" ]]; then
    array_ignore=($(create_array "$file_title"))
else
    echo "[WARNING] --> Sem ficheiro atribuido!"erro 
    ((counter_warnings_i++))
fi




local source_dir="$1"
local backup_dir="$2"

remove_files_NE $source_dir $backup_dir $counter_deleted_i $bytes_deleted_i #Remover o que não existe em source

for file in "$source_dir"/{*,.*}; do

    #Ignorar se for '.' ou '..'
    if [[ "$backup_file" == "$backup_dir/." || "$backup_file" == "$backup_dir/.." || "$backup_file" == "$backup_dir/.*" || "$backup_file" == "$backup_dir/*" ]]; then
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
                #Remover ficheiros que não existem na source
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

                    rm "$current_backup_DIR" || { echo "[ERRO] ao remover $current_backup_DIR"; ((counter_erro++)); continue;} 

                    cp -a "$file" "$backup_dir" || { echo "[ERRO] ao copiar $file"; ((counter_erro++)); continue;} 
                else
                    echo "[WARNING] --> Backup possui versão mais recente do ficheiro $file --> [Não copiado]"
                fi
            else
                echo "[Ficheiro $file copiado para backup]"
                cp -a "$file" "$backup_dir" || { echo "[ERRO] ao copiar $file"; ((counter_erro++)); continue;} 
            fi
        fi
    fi
done

for dir in "$source_dir"/{*.,*}; do
    if [[ -d $dir ]]; then
        filename="${dir##*/}"
        current_backup_DIR="$backup_dir/$filename"

        if [[ $Check_mode -eq 1 ]]; then
            if [[ -e "$current_backup_DIR" ]]; then  #Verificar existência da sub-diretoria
                echo "backup -c $dir $current_backup_DIR"
                backup "$dir" "$current_backup_DIR" #Função recursiva à sub-diretoria
            else
                echo "mkdir -p $current_backup_DIR"
                mkdir -p "$current_backup_DIR" || { echo "[ERRO] ao criar $current_backup_DIR"; ((counter_erro++)); continue;}   #Criar sub-diretoria
                echo "Sub-Diretoria $filename criada com sucesso!"
                backup "$dir" "$current_backup_DIR"
            fi
        else
            if [[ -e "$current_backup_DIR" ]]; then
                backup "$dir" "$current_backup_DIR"
            else
                mkdir -p "$current_backup_DIR" || { echo "[ERRO] ao criar $current_backup_DIR"; ((counter_erro++)); continue;}
                echo "Sub-Diretoria $filename criada com sucesso!"
                backup "$dir" "$current_backup_DIR"
            fi
        fi
    fi
done

exit 0