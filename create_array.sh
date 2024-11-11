#!/bin/bash

#Função auxiliar que converte lista de nomes de fixheiro .txt em array de nomes

create_array() {
    #Define array para guardar nomes de ficheiros a ser ignorados
    local name_files=()

    #Lógica para retirar nomes do ficheiro e colocar no array
    while IFS= read -r line; do
        name_files+=$(realpath "$line")
    done < "$1"

    echo "${name_files[@]}"
    return 0
}