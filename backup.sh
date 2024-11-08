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
source ./function_log.sh

#Log file
##Obtém o data + horário atual
time_LOG=$(date +"%H:%M:%S")
LOG_date=$(date +"%d_%B_%Y")
log_file="Backup[$LOG_date"-"$time_LOG].log"
touch $log_file

remove_files_NE() {
    #Remover ficheiros ou sub-diretorias da diretoria backup que não existem na diretoria de origem
    local source_dir="$1"
    local backup_dir="$2"

    ## $3 -> counter deleted auxiliar e $4 -> counter bytes auxiliar

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
                log $log_file "rm -r "$backup_file""
                rm -r "$backup_file" || { echo "[ERRO] ao remover $backup_file"; continue;} #Remover recursivamente diretoria
            else
                rm "$backup_file" || { echo "[ERRO] ao remover $backup_file"; continue;} #Remover ficheiro
                log $log_file "rm "$backup_file""
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
Source_DIR="$1"
Backup_DIR="$2"

echo "|Log backup da diretoria $Source_DIR |\n" >> $log_file
echo "---------------------------------------------------------------------------------------------------\n" >> $log_file

#Verificar a existência da diretoria de origem
if [[ ! -d $Source_DIR ]]; then
    echo "[Erro] --> A diretoria de origem não existe!"
    exit 1
fi

#Verificar existência da diretoria que receberá os ficheiros (backup)
if ! [[ -e $Backup_DIR ]]; then
    if [[ $Check_mode -eq 1 ]]; then
        echo "mkdir -p $Backup_DIR"
        mkdir -p "$Backup_DIR" || { echo "[Erro] ao criar diretoria bakcup"; exit 1; }
    elif [[ $Check_mode -eq 0 ]]; then
        mkdir -p "$Backup_DIR" | { echo "[Erro] ao criar diretoria bakcup"; exit 1; }
        log $log_file "mkdir -p "$Backup_DIR""
    fi
fi

#Criação de array para nomes de ficheiros
if [[ "$file_title" ]]; then
    if [[ ! -f $file_title ]]; then
        echo "[Erro] --> Ficheiro não encontrado!"
        $file_title="" #Reiniciar variável
    else
        array_ignore=($(create_array "$file_title")) #Criar array com nomes de ficheiros/diretorias a ignorar
    fi
fi

#[Função principal]
backup() {
    local source_dir="$1"
    local backup_dir="$2"

    remove_files_NE $source_dir $backup_dir #Remover o que não existe em source

    for file in "$source_dir"/{*,.*}; do

        #Ignorar se for '.' ou '..'
        if [[ "$backup_file" == "$backup_dir/." || "$backup_file" == "$backup_dir/.." ]]; then
            continue
        fi

        if ignore_files "$file" "${array_ignore[@]}"; then
            continue #ignorar ficheiros/diretorias com o nome encontrado no ficheiro
        fi

        filename="${file##*/}"
        current_backup_DIR="$backup_dir/$filename"

        if [[ -f $file ]]; then 
            if check_file "$file" "$regexpr"; then
                continue #ignorar ficheiros que não respeitam a expressão regex
            fi
            
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

                        log $log_file "rm "$current_backup_DIR""
                        rm "$current_backup_DIR" || { echo "[ERRO] ao remover $current_backup_DIR"; continue;}

                        log $log_file  "cp -a "$file" "$backup_dir""
                        cp -a "$file" "$backup_dir" || { echo "[ERRO] ao copiar $file"; continue;}

                        log $log_file "[Warning --> Substituído]"
                    else
                        log $log_file "[Warning --> Não substituído]"
                        echo "[WARNING] --> Backup possui versão mais recente do ficheiro $file --> [Não substituído]"
                    fi
                else
                    echo "[Ficheiro $file copiado para backup]"
                    log $log_file "cp -a "$file" "$backup_dir"" 
                    cp -a "$file" "$backup_dir" || { echo "[ERRO] ao copiar $file"; continue;}
                fi
            fi
        fi
    done

    # Imprime o status após processar arquivos
    echo "While backuping files of $source_dir: $counter_erro_i Errors; $counter_warnings_i Warnings; $counter_updated_i Updated; $counter_copied_i Copied ($bytes_copied_i B); $counter_deleted_i Deleted ($bytes_deleted_i B)"
    echo "-------------------------------------------------"

    for dir in "$source_dir"/{*.,*}; do
        if [[ -d $dir ]]; then
            filename="${dir##*/}"
            current_backup_DIR="$backup_dir/$filename"

            if ignore_files "$file" "${array_ignore[@]}"; then
                continue #ignorar ficheiros/diretorias com o nome encontrado no ficheiro
            fi

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
                    log $log_file "backup "$dir" "$current_backup_DIR""
                    backup "$dir" "$current_backup_DIR"
                else
                    mkdir -p "$current_backup_DIR" || { echo "[ERRO] ao criar $current_backup_DIR"; ((counter_erro++)); continue;}
                    echo "Sub-Diretoria $filename criada com sucesso!"
                    log $log_file "mkdir -p "$current_backup_DIR""
                    log $log_file "backup "$dir" "$current_backup_DIR""
                    backup "$dir" "$current_backup_DIR"
                fi
            fi
        fi
    done

    return 0
}

backup "$Source_DIR" "$Backup_DIR" #Chamada inicial da função

exit 0