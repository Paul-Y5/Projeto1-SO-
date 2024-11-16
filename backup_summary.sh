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

# Variáveis para contadores internos
counter_erro_i=0
counter_warnings_i=0
counter_copied_i=0
counter_deleted_i=0
counter_updated_i=0
bytes_deleted_i=0
bytes_copied_i=0

#Funções auxiliares:

source ./function_log.sh

remove_files_NE() {
    #Remover ficheiros ou sub-diretorias da diretoria backup que não existem na diretoria de origem
    local source_dir="$1"
    local backup_dir="$2"
    local check="$3"

    for backup_file in "$backup_dir"/{*,.*}; do
        #Ignorar se for '.' ou '..' (diretoria atual e pai respetivamente) 
        if [[ "$backup_file" == "$backup_dir/." || "$backup_file" == "$backup_dir/.." || "$backup_file" == "$backup_dir/.*" || "$backup_file" == "$backup_dir/*" ]]; then
            continue
        fi

        #Nome base do ficheiro/diretoria em backup
        local basename="${backup_file##*/}"
        local source_file="$source_dir/$basename"

        #Verificar se o arquivo correspondente não existe na diretoria de origem
        if [[ ! -e "$source_file" ]]; then
            if [[ -d  "$backup_file" ]]; then
                if [[ $check -eq 1 ]]; then
                    echo "rm -r "$backup_file""
                else
                    local counter_deleted_files=$(find "$backup_file" -type f | wc -l) #Contagem apartir do wc(linha) de todos os ficheiros dentro de backup sub diretoria 
                    counter_deleted_i=$(($counter_deleted + $counter_deleted_files)) #Número de ficheirosdeletados
                    bytes_deleted_i=$(($bytes_deleted + $(du -sb "$backup_file" | cut -f1))) #Tamanho total da sub-diretoria | cut -f1 remove o parametro extra que vem com o resultado do size

                    log $log_file "rm -r "$backup_file""
                    rm -r "$backup_file" || { echo "[ERRO] ao remover $backup_file"; ((counter_erro++)); continue;} #Remover recursivamente diretoria
                    echo "[Diretoria $file removida  [não existe em $source_dir]]" #Mensagem a confirmar
                fi
            else
                if [[ $check -eq 1 ]]; then
                    echo "rm "$backup_file""
                else
                    bytes_deleted_i=$(($bytes_deleted + $(wc -c < "$backup_file"))) #Contagem dos bytes apagados atrvés de wc -c
                    ((counter_deleted_i++))
                    
                    rm "$backup_file" || { echo "[ERRO] ao remover $backup_file"; ((counter_erro++)); continue;} #Remover ficheiro
                    log $log_file "rm "$backup_file""
                    echo "Ficheiro $backup_file removido [não existe em $source_dir]"
                fi
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
    local file_ig=$(realpath "$1")
    dirpath="${file_ig%/*}"
    shift
    local array_ignore=("$@")
    for f in "${array_ignore[@]}"; do
        basename="${f##*/}" 
        if [[ -e "$file_ig" ]]; then
            if [[ "$file_ig" == "$dirpath/$basename" ]]; then
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

    if [[ -n "$regexpr" && ! "$basename" =~ $regexpr ]]; then #-n devolve true se não estiver vazio
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
        c) Check_mode=1 ;; #Check mode ativo
        b) file_title="$OPTARG" ;; #Ficheiro de verificação de nomes
        r) regexpr="$OPTARG" ;; #Expressão regex
        \?) echo "[Erro] --> Opção inválida: -$OPTARG"; exit 1 ;; #Parâmetros indesejados
        :) echo "[Erro] --> A opção -$OPTARG requer um argumento."; exit 1 ;; #Obrigar a passagem de um optaeg quando necessário
    esac
done

shift $((OPTIND - 1)) #Remover argumentos que já foram guardados em variáveis

#Argumentos de diretoria de origem e destino
Source_DIR="$1"
Backup_DIR="$2"

#Verificar a existência da diretoria de origem
if [[ ! -d $Source_DIR ]]; then
    echo "[Erro] --> A diretoria de origem não existe!"
    exit 1 #Saída com erro
fi

if [[ $Check_mode -eq 0 ]]; then #Se check mode ativo não irá fazer log
    #Log file
    ##Obtém o data + horário atual
    time_LOG=$(date +"%H:%M:%S")
    LOG_date=$(date +"%d_%B_%Y")
    #criar ficheiro .log
    log_file="Backup[$LOG_date"-"$time_LOG].log"
    touch $log_file
    #Titulo do .log
    echo "|Log backup da diretoria $Source_DIR |" >> $log_file
    echo "---------------------------------------------------------------------------------------------------" >> $log_file
fi

#Verificar existência da diretoria que receberá os ficheiros (backup)
if [[ ! -e $Backup_DIR ]]; then
    if [[ $Check_mode -eq 1 ]]; then
        echo "mkdir -p $Backup_DIR"
        mkdir -p "$Backup_DIR" || { echo "[Erro] ao criar diretoria bakcup"; exit 1; }
    else
        mkdir -p "$Backup_DIR" || { echo "[Erro] ao criar diretoria bakcup"; exit 1; }
        log $log_file "mkdir -p "$Backup_DIR""
    fi
fi

#Criação de array para nomes de ficheiros
if [[ "$file_title" ]]; then
    if [[ ! -f $file_title ]]; then
        echo "[Erro] --> Ficheiro não encontrado!" && ((counter_erro++))
        $file_title="" #Reiniciar variável
    else
        array_ignore=($(create_array "$file_title")) #Criar array com nomes de ficheiros/diretorias a ignorar
    fi
fi

#[Função principal]
backup() {
    #Argumentos que são passados para possibilitar a recursividade
    local source_dir="$1"
    local backup_dir="$2"

    remove_files_NE $source_dir $backup_dir #Remover o que não existe em source

    for file in "$source_dir"/{*,.*}; do

        #Ignorar se for '.' ou '..'
        if [[ "$backup_file" == "$backup_dir/." || "$backup_file" == "$backup_dir/.." ]]; then
            continue
        fi

        if ignore_files "$file" "${array_ignore[@]}"; then #Urilizar a função ignore files
            echo "[WARNING] --> Ficheiro "$file" ignorado, pois consta no array de nomes para ignorar!"
            ((counter_warnings_i++))
            if [[ $Check_mode -eq 0 ]]; then
                log $log_file "[WARNING] --> Ficheiro "$file" ignorado, pois consta no array de nomes para ignorar!"
            fi
            continue #ignorar ficheiros/diretorias com o nome encontrado no ficheiro
        fi

        #Nome base do ficheiro/diretoria em backup
        filename="${file##*/}"
        current_backup_DIR="$backup_dir/$filename"

        if [[ -f $file ]]; then 
            if check_file "$file" "$regexpr"; then #Chamada à função de verificação de padrão regular 
                echo "[WARNING] --> Ficheiro "$file" ignorado, não repseita expressão regex "$regexpr""
                ((counter_warnings_i++))
                if [[ $Check_mode -eq 0 ]]; then
                    log $log_file "[WARNING] Ficheiro/Diretoria "$file" ignorado, não repseita expressão regex "$regexpr""
                fi
                continue #ignorar ficheiros que não respeitam a expressão regex
            fi

            #Primeiro verificar a existência do file
            if [[ -e "$current_backup_DIR" ]]; then #Verificar se existe
            #verificar se o file que se encontra na diretoria origem é mais recente do que o que se encontra no destino
                if [[ "$file" -nt "$current_backup_DIR" ]]; then
                    if [[ $Check_mode -eq 1 ]]; then  # Modo de verificação
                        echo "[WARNING] --> Versão do ficheiro encontrada em $backup_dir desatualizada [Substituir]"
                        ((counter_warnings_i++))

                        bytes_deleted_i=$((bytes_deleted_i + $(wc -c < "$current_backup_DIR")))
                        echo "rm $current_backup_DIR"
                        ((counter_deleted_i++))
                        
                        echo "cp -a $file $backup_dir"
                        bytes_copied_i=$((bytes_copied_i + $(wc -c < "$file"))) #soma tamanho do ficheiro em bytes
                        ((counter_copied_i++))

                        ((counter_updated_i++))
                    else
                        echo "[WARNING] --> Versão do ficheiro $file encontrada em $backup_dir desatualizada [Atualizar]"
                        ((counter_warnings_i++))

                        bytes_deleted_i=$((bytes_deleted_i + $(wc -c < "$current_backup_DIR")))
                        log $log_file "rm "$current_backup_DIR""
                        rm "$current_backup_DIR" || { echo "[ERRO] ao remover $current_backup_DIR"; ((counter_erro++)); continue;} 
                        ((counter_deleted_i++))

                        log $log_file  "cp -a "$file" "$backup_dir""
                        cp -a "$file" "$backup_dir" || { echo "[ERRO] ao copiar $file"; ((counter_erro++)); continue;}
                        bytes_copied_i=$((bytes_copied_i + $(wc -c < "$file")))
                        ((counter_copied_i++))

                        log $log_file "${log_file%.*} [$current_backup_DIR Substituído]"
                        ((counter_updated_i++))
                    fi
                else
                    if [[ $Check_mode -eq 1 ]]; then  # Modo de verificação
                        echo "[WARNING] --> $backup_dir possui versão mais recente do ficheiro $file --> [Não copiado]"
                        ((counter_warnings_i++))
                    else
                        log $log_file "[$current_backup_DIR Não substituído]"
                        echo "[WARNING] --> $backup_dir possui versão mais recente do ficheiro $file --> [Não substituído]"
                        ((counter_warnings_i++))
                    fi
                fi
            else
                if [[ $Check_mode -eq 1 ]]; then  # Modo de verificação
                    echo "cp -a $file $backup_dIR"
                    ((counter_copied_i++))
                    bytes_copied_i=$((bytes_copied_i + $(wc -c < "$file")))
                else
                    echo "${log_file%.*} [Ficheiro $file copiado para $backup_dir]"
                    log $log_file "cp -a "$file" "$backup_dir"" 
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
    echo "While backuping files of $source_dir: $counter_erro_i Errors; $counter_warnings_i Warnings; $counter_updated_i Updated; $counter_copied_i Copied ($bytes_copied_i B); $counter_deleted_i Deleted ($bytes_deleted_i B)"
    echo "-------------------------------------------------"

    for dir in "$source_dir"/{*,.*}; do
        #Resetar contadores internos ao entrar em sub-diretorias
        counter_erro_i=0
        counter_warnings_i=0
        counter_copied_i=0
        counter_deleted_i=0
        counter_updated_i=0
        bytes_deleted_i=0
        bytes_copied_i=0

        if [[ -d $dir ]]; then
            echo $dir
            #Caminho paraa diretoria atual
            filename="${dir##*/}"
            current_backup_DIR="$backup_dir/$filename"

            if ignore_files "$dir" "${array_ignore[@]}"; then #Chamada da função ignore para subdiretorias 
                echo "[WARNING] --> Diretoria "$file" ignorado, pois consta no array de nomes para ignorar!"
                ((counter_warnings_i++))
                if [[ $Check_mode -eq 0 ]]; then
                    log $log_file "[WARNING] --> Diretoria "$file" ignorado, pois consta no array de nomes para ignorar!"
                fi
                continue #ignorar ficheiros/diretorias com o nome encontrado no ficheiro
            fi

            if [[ -e "$current_backup_DIR" ]]; then  #Verificar existência da sub-diretoria
                echo "backup -c $dir $current_backup_DIR"
                if [[ $Check_mode -eq 1 ]]; then
                    backup "$dir" "$current_backup_DIR" #Função recursiva à sub-diretoria
                else
                    log $log_file "backup "$dir" "$current_backup_DIR""
                    backup "$dir" "$current_backup_DIR"
                fi
            else
                if [[ $Check_mode -eq 1 ]]; then
                    echo "mkdir -p $current_backup_DIR"
                    mkdir -p "$current_backup_DIR" || { echo "[ERRO] ao criar $current_backup_DIR"; ((counter_erro++)); continue;}   #Criar sub-diretoria
                    echo "Sub-Diretoria $filename criada com sucesso!"
                    backup "$dir" "$current_backup_DIR"
                else
                    mkdir -p "$current_backup_DIR" || { echo "[ERRO] ao criar $current_backup_DIR"; ((counter_erro++)); continue;}
                    echo "${log_file%.*} Sub-Diretoria $filename criada com sucesso!"
                    log $log_file "mkdir -p "$current_backup_DIR""
                    log $log_file "backup "$dir" "$current_backup_DIR""
                    backup "$dir" "$current_backup_DIR"
                fi
            fi
        fi
    done

    return 0 #Execução sem erros
}

backup "$Source_DIR" "$Backup_DIR" #Chamada inicial da função

# Mensagem final com o resumo
echo "${log_file%.*}:"
echo "Backup Summary: $counter_erro Errors; $counter_warnings Warnings; $counter_updated Updated; $counter_copied Copied ($bytes_copied B); $counter_deleted Deleted ($bytes_deleted B)"
echo "-------------------------------------------------"

if [[ $Check_mode -eq 0 ]]; then
    #Para log
    echo "-------------------------------------------------" >> $log_file
    echo "Backup Summary: $counter_erro Errors; $counter_warnings Warnings; $counter_updated Updated; $counter_copied Copied ($bytes_copied B); $counter_deleted Deleted ($bytes_deleted B)" >> $log_file
    echo "-------------------------------------------------" >> $log_file
fi

exit 0 #Foi executado sem erros