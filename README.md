# AWS terraform snippets for vim

Compatible with Terraform 0.9.3

You need to have vim-snippets and UltiSnips installed which in turn means you need python2 or python3 and vim compiled with your python version.


## Status 45% complete
This is a very early stage, if you are a brave soul and find inconsistencies please let me know.
As you might suspect, this is not me typing the snippets, a script provides general scaffolding and structure of the different resources or data. For every snippet I have gone through the docs to verify the use and try to be as close to docs as possible (which is mostly the reason to do this, get acquainted with the code and read the docs).

## Use
All AWS resources can be triggered at the start of the line.
meta-params (`depends_on`, `lifecycle`, etc) can be started regardless of the position.

## Example
srAwsInstance<TAB>

## Legend
Snippets can be located by following this simple combination:
1. First letter denotes the verbosity of the snippet:
  * `s`: `short`: only the required params are populated
  * `f`: `full` : every attribute type is populated
2. Second letter denotes the resource type:
  * `d`: `data`    : triggers a "data" source
  * `r`: `resource`: triggers a "resource" definition
3. The name of the resource:
  * `AwsAlbTargetGroup` triggers the data|resource "aws_alb_target_group"
