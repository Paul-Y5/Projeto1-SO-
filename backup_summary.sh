#!/bin/bash

# para cada diretoria, seja escrito na consola 
#um sumário com a indicação do número de erros,
# warnings, ficheiros atualizados, ficheiros copiados e ficheiros apagados

# Exemplo:
# While backuping src: 0 Errors; 1 Warnings; 1 Updated; 2 Copied (200B); 0 deleted (0B)


#Variáveis de contagem
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


backup_files() {
    for file in "$Source_DIR"/{*,.*}; do
        if ignore_files "$filename"; then
            continue # Ignorar ficheiros
        fi

        if [[ -n $regexpr ]] && ! [[ "$filename" =~ $regexpr ]]; then
            continue # Ignorar ficheiros que não correspondem ao regex
        fi

        filename="${file##*/}"
        if [[ $Check_mode -eq 1 ]]; then #Exucução do programa de acordo com o argumento -c (Apenas imprime comandos que seriam executados)
            #Iterar sobre os ficheiros para fazer o backup a partir do cp -a (comando copy)
            if [[ -e "$Backup_DIR/$filename" ]]; then ##Problemas com recursividade
                if [[ -d $file ]]; then
                    #Chamada recursiva
                    cd $file
                    Backup_DIR="$Backup_DIR/$file"
                    backup_files "-c" $Source_DIR $Backup_DIR
                    ## Falta algo ...
                fi
                if [[ "$file" -nt "$Backup_DIR/$filename" ]]; then
                    echo "WARNING: Versão do ficheiro encontrada em backup desatualizada [Subistituir]"
                    counter_warnings=$((counter_warnings + 1))

                    bytes_deleted=$((bytes_deleted + $(wc -c <  "$Backup_DIR/$filename")))
                    echo "rm  "$Backup_DIR/$filename""
                    counter_deleted=$((counter_deleted + 1))
                    
                    echo "cp -a $file $Backup_DIR"
                    bytes_copied=$((bytes_copied + $(wc -c < $file)))
                    counter_copied=$((counter_copied + 1))

                    counter_updated=$((counter_updated + 1))
                else
                    echo "WARNING: Backup possui versão mais recente do ficheiro $file --> [Não copiado]"
                    counter_warnings=$((counter_warnings + 1))
                fi
            else
                if [[ -d $file ]]; then
                    echo "mkdir "$Backup_DIR/$filename""
                    echo "cd $file"
                    Backup_DIR="$Backup_DIR/$file"
                    echo "backup_files "-c" $Source_DIR $Backup_DIR" 
                else
                    echo "cp -a $file $Backup_DIR"
                    counter_copied=$((counter_copied + 1))
                    bytes_copied=$((bytes_copied + $(wc -c < $file)))
                fi
            fi
            echo "While backuping src: $counter_erro Errors; $counter_warnings Warnings; $counter_updated Updated; $counter_copied Copied ($bytes_copied B); $counter_deleted deleted ($bytes_deleted B)"
            exit 0 #saída com sa partir dos argumentos restantesucesso
        else  #Se -c não for argumento executa comandos (modo check=0)
            if [[ -e "$Backup_DIR/$filename" ]]; then
                if [[ -d $file ]]; then
                    #Chamada recursiva
                    cd $file
                    backup_files $Source_DIR $Backup_DIR
                fi

                if [[ "$file" -nt "$Backup_DIR/$filename" ]]; then
                    echo "WARNING: Versão do ficheiro encontrada em backup desatualizada [Subistituir]"
                    counter_warnings=$((counter_warnings + 1))

                    bytes_deleted=$((bytes_deleted + $(wc -c <  "$Backup_DIR/$filename")))
                    rm  "$Backup_DIR/$filename"
                    counter_deleted=$((counter_deleted + 1))

                    cp -a $file $Backup_DIR
                    bytes_copied=$((bytes_copied + $(wc -c < $file)))
                    counter_copied=$((counter_copied + 1))

                    counter_updated=$((counter_updated + 1))
                else
                    echo "WARNING: Backup possui versão mais recente do ficheiro $file --> [Não copiado]"
                    counter_warnings=$((counter_warnings + 1))
                fi
            else
                cp -a "$file" "$Backup_DIR"
                counter_copied=$((counter_copied + 1))
                bytes_copied=$((bytes_copied + $(wc -c < $file)))
                if [[ -d  ]]
                echo "[Ficheiro $file copiado para backup]"
            fi
        fi
    done
    echo "While backuping src: $counter_erro Errors; $counter_warnings Warnings; $counter_updated Updated; $counter_copied Copied ($bytes_copied B); $counter_deleted deleted ($bytes_deleted B)"
    exit 0
}

backup_files