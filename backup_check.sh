#!/bin/bash

# Chamado quando o script backup.sh ou backuo:files.sh possui o argumento -c

# verifica se o conteúdo dos ficheiros na
# diretoria de backup é igual ao conteúdo dos ficheiros correspondentes na diretoria de
# trabalho usando o -> comando md5sum <-

# Comando não tem de verificar se existem
# ficheiros novos ou de fazer qualquer cópia de ficheiros. Sempre que for detetado um erro
# deve ser escrita uma mensagem idêntica a:
# --> src/text.txt bak1/text.txt differ