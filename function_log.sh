#!/bin/bash

log() {
    #Função que cria LOG do backup

    #Comando executado
    local command="$1"

    #Obtém o data + horário atual
    time_LOG=$(date +"%H:%M:%S")
    LOG_date=$(date +"%d %B %Y")

    log_file="Backup["$LOG_date"_"$time_LOG"].log"

    touch $log_file

    #Regista o comando no arquivo log
    echo "[$timeLOG] - $command" >> "$log_file"
}