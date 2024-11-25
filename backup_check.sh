#!/bin/bash

# verifica se o conteúdo dos ficheiros na
# diretoria de backup é igual ao conteúdo dos ficheiros correspondentes na diretoria de
# trabalho usando o -> comando md5sum <-

# Comando não tem de verificar se existem
# ficheiros novos ou de fazer qualquer cópia de ficheiros. Sempre que for detetado um erro
# deve ser escrita uma mensagem idêntica a:
# --> src/text.txt bak1/text.txt differ


if [ "$#" -ne 2 ]; then
    echo "Erro! Deve apenas ter dois diretórios como argumentos!"
    exit 1
fi

#Verifica a existência da diretoria de origem
if [[ ! -d $1 ]]; then
    echo "Erro! O primeiro argumento não é um diretório!"
    exit 1
fi

#Verifica a existência da diretoria de origem
if [[ ! -d $2 ]]; then
    echo "Erro! O segundo argumento não é um diretório!"
    exit 1
fi



count_diff=0
count_eq=0
sec_run=0

compare_files() {
    local src_dir="$1"
    local bkup_dir="$2"
    

    src_checksum=$(md5sum "$src_dir" | awk '{ print $1}')
    bkup_checksum=$(md5sum "$bkup_dir" | awk '{ print $1}')

    if [ "$src_checksum" != "$bkup_checksum" ]; then
        echo "$src_dir $bkup_dir differ"
        ((count_diff++))
    else
        ((count_eq++))
    fi
}


traverse_and_compare() {
    local current_src_dir="$1"
    local current_bkup_dir="$2"

    for src_path in "$current_src_dir"/*; do
        relative_path="${src_path#$current_src_dir/}"
        relative_bkup_path="$current_bkup_dir/$relative_path"

        if [ -d "$src_path" ]; then 
            if [ -d "$relative_bkup_path" ]; then 
                traverse_and_compare "$src_path" "$relative_bkup_path"
            else
                ((count_diff++))
                #echo "Erro! O subdiretório $relative_path não existe no $current_bkup_dir."
            fi

        elif [ -f "$src_path" ]; then
            if [ -f "$relative_bkup_path" ]; then
                if [ "$sec_run" -eq 0 ]; then 
                    compare_files "$src_path" "$relative_bkup_path"
                fi
            else
                ((count_diff++))
                #echo "Erro! O ficheiro $relative_path não existe no $current_bkup_dir."
            fi
        fi
    done

}

traverse_and_compare "$1" "$2"

# sec_run=1

# traverse_and_compare "$2" "$1"

# echo "Número de erros total: $count_diff"
# echo "Número de ficheiros iguais: $count_eq"

# if [ "$count_diff" -eq 0 ]; then 
#     echo "Os diretórios são iguais"
# else
#     echo "Os diretórios são diferentes"
# fi