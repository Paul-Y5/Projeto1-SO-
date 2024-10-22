#!/bin/bash

# Semelhante ao backup_files.sh, considerando agora que a
# diretoria de trabalho pode ter ficheiros e diretorias (que por sua vez podem ter
# subdiretorias). Este script deve considerar todas as opções da linha de comando.

# Print no terminal de todas as execuções de comandos cp -a, rm, etc.
# Minimo de argumentos: 2 (diretoria de origem) e (diretoria de destino);

# Max args: 2 + [-c] --> ativar a opção de checking (não executa comandos apendas dá print); 
# opção -b (permite a indicação de um ficheiro de texto
# que contém uma lista de ficheiros (ou diretorias) que não devem ser copiados
# para a diretoria de backup. 
# opção -r indica que apenas devem ser copiados os ficheiros que verificam uma expressão regular

# Exemplo:
# ./backup.sh [-c] [-b tfile] [-r regexpr] dir_trabalho dir_backup

# --> Pensar recursivamente <--

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

if [[ $# -eq 3 && $1 -ne "-c" ]]; then #Condição de uso do -c
    echo "[Erro] --> Argumento 3 ($1) impossível | Argumentos possíveis: -c"
    exit 1
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
        \?) #opções inválidas fora das opções [-c -b -r]
            echo "[Erro] --> Opção inválida: -$OPTARG"
            exit 1
            ;;
        :) #situações em que uma opção que requer um argumento é fornecida sem um argumento.
            echo "[Erro] --> A opção -$OPTARG requer um argumento."
            exit 1
            ;;
        *) #Outros erros
            echo "[Erro] --> Formato de argumentos inválido!"
            exit 1
    esac
done

#Remover as opções processadas da lista de argumentos
shift $((OPTIND - 1))

#Verifica a existência da diretoria de origem
if [[ ! -d $Source_DIR ]]; then
    echo "[Erro] --> A diretoria de origem não existe!"
    exit 1
fi

#Verifica a existência da diretoria de origem
if [[ ! -d $Backup_DIR ]]; then
    echo "mkdir $Backup_DIR"
fi

#Executar em check mode ou não
if [[ $Check_mode -eq 1 ]]; then #Exucução do progrma de acordo com o argumento -c (Apenas imprime comandos que seriam executados)
    #Iterar sobre os ficheiros para fazer o backup a partir do cp (comando copy)
    for file in "$Source_DIR"/{*,.*}; do
        if [[ -e "$Backup_DIR/${file##*/}" ]]; then
            if [[ "$file" -nt "$Backup_DIR/${file##*/}" ]]; then
                echo "WARNING: Versão do ficheiro encontrada em backup desatualizada [Subistituir]"
                counter_warnings=$((counter_warnings + 1))

                bytes_deleted=$((bytes_deleted + $(wc -c <  "$Backup_DIR/${file##*/}")))
                echo "rm  "$Backup_DIR/${file##*/}""
                counter_deleted=$((counter_deleted + 1))
                
                echo "cp $file $Backup_DIR"
                bytes_copied=$((bytes_copied + $(wc -c < $file)))
                counter_copied=$((counter_copied + 1))

                counter_updated=$((counter_updated + 1))
            else ### Parei aqui de dar debbug
                echo "WARNING: Backup possui versão mais recente do ficheiro $file --> [Não copiado]"
                counter_warnings=$((counter_warnings + 1))
            fi
        else
            echo "cp $file $Backup_DIR"
            counter_copied=$((counter_copied + 1))
            bytes_copied=$((bytes_copied + $(wc -c < $file)))
        fi
    done
    echo "While backuping src: $counter_erro Errors; $counter_warnings Warnings; $counter_updated Updated; $counter_copied Copied ($bytes_copied B); $counter_deleted deleted ($bytes_deleted B)"
    exit 0 #saída com sucesso
else  #Se -c não for argumento executa comandos (modo check=0)
    if [[ ! -d $Backup_DIR ]]; then
        mkdir -p "$Backup_DIR"  #-p garante que são criados as diretorias pai caso não existam
    fi
    for file in "$Source_DIR"/{*,.*}; do
        if [[ -e "$Backup_DIR/${file##*/}" ]]; then
            if [[ "$file" -nt "$Backup_DIR/${file##*/}" ]]; then
                echo "WARNING: Versão do ficheiro encontrada em backup desatualizada [Subistituir]"
                counter_warnings=$((counter_warnings + 1))

                bytes_deleted=$((bytes_deleted + $(wc -c <  "$Backup_DIR/${file##*/}")))
                rm  "$Backup_DIR/${file##*/}"
                counter_deleted=$((counter_deleted + 1))

                cp $file $Backup_DIR
                bytes_copied=$((bytes_copied + $(wc -c < $file)))
                counter_copied=$((counter_copied + 1))

                counter_updated=$((counter_updated + 1))
            else
                echo "WARNING: Backup possui versão mais recente do ficheiro $file --> [Não copiado]"
                counter_warnings=$((counter_warnings + 1))
            fi
        else
            cp "$file" "$Backup_DIR"
            counter_copied=$((counter_copied + 1))
            bytes_copied=$((bytes_copied + $(wc -c < $file)))
            echo "[Ficheiro $file copiado para backup]"
        fi
    done
    echo "While backuping src: $counter_erro Errors; $counter_warnings Warnings; $counter_updated Updated; $counter_copied Copied ($bytes_copied B); $counter_deleted deleted ($bytes_deleted B)"
    exit 0
fi