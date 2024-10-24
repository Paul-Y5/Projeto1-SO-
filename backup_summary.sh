#!/bin/bash

# para cada diretoria, seja escrito na consola 
#um sumário com a indicação do número de erros,
# warnings, ficheiros atualizados, ficheiros copiados e ficheiros apagados

# Exemplo:
# While backuping src: 0 Errors; 1 Warnings; 1 Updated; 2 Copied (200B); 0 deleted (0B)


#Variáveis de contagem Globais
counter_erro=0
counter_warnings=0
counter_copied=0
counter_deleted=0
counter_updated=0
bytes_deleted=0
bytes_copied=0

if [[ $# -lt 2 || $# -gt 5 ]]; then #Condição de intervalo de quantidade de argumentos [2 a 3]
    echo "[Erro] --> Número de argumentos inválido!"
    exit 1 #saída com erro
fi

#Utilização de variáveis para argumentos
Check_mode=0
tfile=""
regexpr=""

# Opções de argumentos
while getopts "cb:r:" opt; do
    case $opt in
        c)
            Check_mode=1
            ;;
        b)
            tfile="$OPTARG" #OPTARG é a expressão que se encontra á frente do -b
            ;;
        r)
            regexpr="$OPTARG" #OPTARG é a expressão que se encontra á frente do -r
            ;;
        \?) #Opções inválidas fora das opções [-c -b -r]
            echo "[Erro] --> Opção inválida: -$OPTARG"
            exit 1
            ;;
        :) #Situações em que uma opção que requer um argumento é fornecida sem um argumento.
            echo "[Erro] --> A opção -$OPTARG requer um argumento."
            exit 1
            ;;
        *) #Outros erros
            echo "[Erro] --> Formato de argumentos inválido!"
            exit 1
    esac
done

#Remove as opções processadas da lista de argumentos
shift $((OPTIND - 1))
#Atribui diretórios aos restantes argumentos
Source_DIR=$1
Backup_DIR=$2

#Verifica a existência da diretoria de origem
if [[ ! -d $Source_DIR ]]; then
    echo "[Erro] --> A diretoria de origem não existe!"
    exit 1
fi

#Verifica a existência da diretoria de origem
if [[ ! -d $Backup_DIR  && $Check_mode -eq 1 ]]; then
    echo "mkdir $Backup_DIR"
    mkdir "$Backup_DIR"   
elif [[ ! -d $Backup_DIR && $Check_mode -eq 0 ]]; then
    mkdir "$Backup_DIR"
fi

#Função para argumento -b ()
ignore_files() {
    file_ig="$1"
    basename="${file##*/}"
    #Verifica se o ficheiro deve ou não ser copiado
    if [[ -n "$tfile" && -f "$tfile" ]]; then
        if grep -qx "$basename" "$tfile"; then #Verifica se a linha corresponde exatamente à string
            return 0 # Ignorar arquivo
        fi
    fi
    
    return 1 #copiar
}


# Aqui utilizámos uma abordagem recursiva através de uma função para preservar a contagem dos erros, warnings, etc como variáveis globais
backup() {
    for file in "$Source_DIR"/{*,.*}; do
        #variáveis para contadores internos
        counter_erro_i=0
        counter_warnings_i=0
        counter_copied_i=0
        counter_deleted_i=0
        counter_updated_i=0
        bytes_deleted_i=0
        bytes_copied_i=0

        if ignore_files "$file"; then
            continue # Ignorar ficheiros do ficheiro
        fi

        if [[ -n $regexpr ]] && ! [[ "$file" =~ $regexpr ]]; then
            continue # Ignorar ficheiros que não correspondem ao regex
        fi


        filename="${file##*/}"
        current_backup_DIR="$Backup_DIR/$filename"

        if [[ $Check_mode -eq 1 ]]; then #Exucução do programa de acordo com o argumento -c (Apenas imprime comandos que seriam executados)
            #Iterar sobre os ficheiros para fazer o backup a partir do cp -a || mkdir de diretorios (comando copy)
            if [[ -e "$current_backup_DIR" ]]; then
                if [[ -d "$file" ]]; then
                    #Chamada recursiva
                    echo "backup_files "-c" $file $current_backup_DIR" 
                    backup_files "$file" "$current_backup_DIR"
                fi
                if [[ -f "$file" && "$file" -nt "$current_backup_DIR" ]]; then
                    echo "WARNING: Versão do ficheiro encontrada em backup desatualizada [Subistituir]"
                    counter_warnings_i=$((counter_warnings_i + 1))

                    bytes_deleted_i=$((bytes_deleted_i + $(wc -c <  "$Backup_DIR/$filename")))
                    echo "rm  "$Backup_DIR/$filename""
                    counter_deleted_i=$((counter_deleted_i + 1))
                    
                    echo "cp -a $file $Backup_DIR"
                    bytes_copied_i=$((bytes_copied_i + $(wc -c < $file)))
                    counter_copied_i=$((counter_copied_i + 1))

                    counter_updated_i=$((counter_updated_i + 1))
                else
                    echo "WARNING: Backup possui versão mais recente do ficheiro $file --> [Não copiado]"
                    counter_warnings_i=$((counter_warnings_i + 1))
                fi
            else
                if [[ -d $file ]]; then
                    echo "mkdir $current_backup_DIR"
                    echo "backup_files "-c" $file $current_backup_DIR" 
                    backup_files "-c" "$file" "$current_backup_DIR"
                else
                    echo "cp -a $file $Backup_DIR"
                    counter_copied_i=$((counter_copied_i + 1))
                    bytes_copied_i=$((bytes_copied_i + $(wc -c < $file)))
                fi
            fi
        else  #Se -c não for argumento executa comandos (Check_mode=0)
            if [[ -e "$current_backup_DIR" ]]; then
                if [[ -d $file ]]; then
                    #Chamada recursiva
                    backup_files "-c" "$file" "$current_backup_DIR" || exit 1
                fi

                if [[ -f $file && "$file" -nt "$Backup_DIR/$filename" ]]; then
                    echo "WARNING: Versão do ficheiro encontrada em backup desatualizada [Subistituir]"
                    counter_warnings_i=$((counter_warnings_i + 1))

                    bytes_deleted_i=$((bytes_deleted_i + $(wc -c <  "$Backup_DIR/$filename")))
                    rm  "$Backup_DIR/$filename"
                    counter_deleted_i=$((counter_deleted_i + 1))

                    cp -a $file $Backup_DIR
                    bytes_copied_i=$((bytes_copied_i + $(wc -c < $file)))
                    counter_copied_i=$((counter_copied_i + 1))

                    counter_updated_i=$((counter_updated_i + 1))
                else
                    echo "WARNING: Backup possui versão mais recente do ficheiro $file --> [Não copiado]"
                    counter_warnings_i=$((counter_warnings_i + 1))
                fi
            else
                if [[ -d  $file ]]; then
                    mkdir -p "$current_backup_DIR" || exit 1
                    echo "[Diretoria $file criada em backup]"
                    backup_files "$file" "$current_backup_DIR"
                else
                    echo "[Ficheiro $file copiado para backup]"
                    cp -a "$file" "$Backup_DIR"
                    counter_copied_i=$((counter_copied_i + 1))
                    bytes_copied_i=$((bytes_copied_i + $(wc -c < $file)))
                fi
            fi
        fi
        echo "While backuping $current_backup_DIR: $counter_erro_i Errors; $counter_warnings_i Warnings; $counter_updated_i Updated; $counter_copied_i Copied ($bytes_copied_i B); $counter_deleted_i deleted ($bytes_deleted_i B)"
        echo "-------------------------------------------------"

        # Atualiza os contadores globais
        counter_erro=$((counter_erro + counter_erro_i))
        counter_warnings=$((counter_warnings + counter_warnings_i))
        counter_updated=$((counter_updated + counter_updated_i))
        counter_copied=$((counter_copied + counter_copied_i))
        counter_deleted=$((counter_deleted + counter_deleted_i))
        bytes_deleted=$((bytes_deleted + bytes_deleted_i))
        bytes_copied=$((bytes_copied + bytes_copied_i))
    done
    exit 0 #saída com successo
}

backup
echo "While backuping: $counter_erro Errors; $counter_warnings Warnings; $counter_updated Updated; $counter_copied Copied ($bytes_copied B); $counter_deleted deleted ($bytes_deleted B)"
echo "-------------------------------------------------"