#!/bin/bash
#para cada diretoria, seja escrito na consola 
#um sumário com a indicação do número de erros,
#warnings, ficheiros atualizados, ficheiros copiados e ficheiros apagados
#Exemplo: While backuping src: 0 Errors; 1 Warnings; 1 Updated; 2 Copied (200B); 0 deleted (0B)

#Variáveis de contagem globais
counter_erro=0
counter_warnings=0
counter_copied=0
counter_deleted=0
counter_updated=0
bytes_deleted=0
bytes_copied=0

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
                rm -r "$backup_file" || { echo "[ERRO] ao remover $backup_file"; ((counter_erro++)); continue;} #Remover recursivamente diretoria
            else
                rm "$backup_file" || { echo "[ERRO] ao remover $backup_file"; ((counter_erro++)); continue;} #Remover ficheiro
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
#Facilita na passagem dos argumentos de diretoria de origem e destino
Source_DIR=$1
Backup_DIR=$2

#Verificar a existência da diretoria de origem
if [[ ! -d $Source_DIR ]]; then
    echo "[Erro] --> A diretoria de origem não existe!"
    exit 1
fi

#Verificar existência da diretoria que receberá os ficheiros (backup)
if [[ -e $Backup_DIR ]]; then
    if [[ $Check_mode -eq 1 ]]; then
        echo "remove_files_NE $Source_DIR $Backup_DIR"
        remove_files_NE $Source_DIR $Backup_DIR
    elif [[ $Check_mode -eq 0 ]]; then
        remove_files_NE $Source_DIR $Backup_DIR
    fi
else
    if [[ $Check_mode -eq 1 ]]; then
        echo "mkdir -p $Backup_DIR"
        mkdir "$Backup_DIR" || { echo "[Erro] ao criar diretoria bakcup"; ((counter_erro++)); exit 1; } 
    elif [ $Check_mode -eq 0 ]]; then
        mkdir -p "$Backup_DIR" | { echo "[Erro] ao criar diretoria bakcup"; ((counter_erro++)); exit 1; }  
    fi
fi

#Criação de array para nomes de ficheiros
if [[ "$file_title" ]]; then
    array_ignore=($(create_array "$file_title"))
else
    echo "[WARNING] --> Sem ficheiro atribuido!"erro 
    ((counter_warnings_i++))
fi


#[Função principal]

# Variáveis para contadores internos
counter_erro_i=0
counter_warnings_i=0
counter_copied_i=0
counter_deleted_i=0
counter_updated_i=0
bytes_deleted_i=0
bytes_copied_i=0

backup() {
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
                    #Remover ficheiros que não existem na source
                    if [[ "$file" -nt "$current_backup_DIR" ]]; then
                        echo "[WARNING] --> Versão do ficheiro encontrada em backup desatualizada [Substituir]"
                        ((counter_warnings_i++))

                        bytes_deleted_i=$((bytes_deleted_i + $(wc -c < "$current_backup_DIR")))
                        echo "rm $current_backup_DIR"
                        ((counter_deleted_i++))
                        
                        echo "cp -a $file $backup_dir"
                        bytes_copied_i=$((bytes_copied_i + $(wc -c < "$file"))) #soma tamanho do ficheiro em bytes
                        ((counter_copied_i++))

                        ((counter_updated_i++))
                    else
                        echo "[WARNING] --> Backup possui versão mais recente do ficheiro $file --> [Não copiado]"
                        ((counter_warnings_i++))
                    fi
                else
                    echo "cp -a $file $backup_dIR"
                    ((counter_copied_i++))
                    bytes_copied_i=$((bytes_copied_i + $(wc -c < "$file")))
                fi
            else
                if [[ -e "$current_backup_DIR" ]]; then
                    if [[ "$file" -nt "$current_backup_DIR" ]]; then
                        echo "[WARNING] --> Versão do ficheiro encontrada em backup desatualizada [Substituir]"
                        ((counter_warnings_i++))

                        bytes_deleted_i=$((bytes_deleted_i + $(wc -c < "$current_backup_DIR")))
                        rm "$current_backup_DIR" || { echo "[ERRO] ao remover $current_backup_DIR"; ((counter_erro++)); continue;} 
                        ((counter_deleted_i++))

                        cp -a "$file" "$backup_dir" || { echo "[ERRO] ao copiar $file"; ((counter_erro++)); continue;} 
                        bytes_copied_i=$((bytes_copied_i + $(wc -c < "$file")))
                        ((counter_copied_i++))

                        ((counter_updated_i++))
                    else
                        echo "[WARNING] --> Backup possui versão mais recente do ficheiro $file --> [Não copiado]"
                        ((counter_warnings_i++))
                    fi
                else
                    echo "[Ficheiro $file copiado para backup]"
                    cp -a "$file" "$backup_dir" || { echo "[ERRO] ao copiar $file"; ((counter_erro++)); continue;} 
                    ((counter_copied_i++))
                    bytes_copied_i=$((bytes_copied_i + $(wc -c < "$file")))
                fi
            fi
        fi
    done

    # Atualiza os contadores globais
        counter_erro=$((counter_erro + counter_erro_i))
        counter_warnings=$((counter_warnings + counter_warnings_i))
        counter_updated=$((counter_updated + counter_updated_i))
        counter_copied=$((counter_copied + counter_copied_i))
        counter_deleted=$((counter_deleted + counter_deleted_i))
        bytes_deleted=$((bytes_deleted + bytes_deleted_i))
        bytes_copied=$((bytes_copied + bytes_copied_i))

    # Imprime o status após processar arquivos
    echo "While backuping files of $Source_DIR: $counter_erro_i Errors; $counter_warnings_i Warnings; $counter_updated_i Updated; $counter_copied_i Copied ($bytes_copied_i B); $counter_deleted_i Deleted ($bytes_deleted_i B)"
    echo "-------------------------------------------------"

    for dir in "$source_dir"/{*.,*}; do

        #Resetar contadores internos ao entrar em sub-diretorias
        counter_erro_i=0
        counter_warnings_i=0
        counter_copied_i=0
        counter_deleted_i=0
        counter_updated_i=0
        bytes_deleted_i=0
        bytes_copied_i=0

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

    return 0
}

backup "$Source_DIR" "$Backup_DIR" #Chamada inicial da função

# Mensagem final com o resumo
echo "Backup Summary: $counter_erro Errors; $counter_warnings Warnings; $counter_updated Updated; $counter_copied Copied ($bytes_copied B); $counter_deleted Deleted ($bytes_deleted B)"
echo "-------------------------------------------------"

exit 0