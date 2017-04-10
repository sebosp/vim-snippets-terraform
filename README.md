# terraform snippets for vim

You need to have vim-snippets installed which in turn means you need python2 or python3 and vim compiled with your python version.

## Status
This is a very early stage, if you are a brave soul and find inconsistencies please let me know.
As you might suspect, this is not me typing the snippets, the script needs a lot of tweaking.
This script is in the firsts stage where it recognizes the params for each resource.
Afterwards these rules can be added to provide terraform-lint rules
Which should then interact with vim-syntastic.

## Populating the files
Assuming you have both vim-snippets-terraform and hashicorp/terraform repos in ~/git:
seb@alarm:[~/git/vim-snippets-terraform] (master %=)$ find ../terraform/builtin/providers/aws/ -type f > terra.list
seb@alarm:[~/git/vim-snippets-terraform] (master %=)$ perl terra-sni.pl


## Use:

