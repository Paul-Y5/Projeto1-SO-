#!/bin/bash

log() {
    #Função que cria LOG do backup

    #Comando executado
    local log_file="$1"
    local command="$2"

    time_LOG=$(date +"%H:%M:%S")
    #Regista o comando no arquivo log
    echo "[$time_LOG] - $command" >> "$log_file"
}