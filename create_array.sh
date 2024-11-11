#!/bin/bash

#Função auxiliar que converte lista de nomes de fixheiro .txt em array de nomes

create_array() {
    #Define array para guardar nomes de ficheiros a ser ignorados
    local name_files=()

    #Lógica para retirar nomes do ficheiro e colocar no array
    while IFS= read -r line; do
        if [ -z "$line" ]; then #Verifica se está vazio (se estiver ignora)
            continue
        fi
        name_files+=("$line") #Adicionar linha ao array
    done < "$1"

    echo "${name_files[@]}" #Retorna array
    return 0
}