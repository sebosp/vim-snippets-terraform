#!/bin/bash

cat terraform.snippets | sed -e 's/^\(snippet \w*\).*/\1/' -e "/^endsnippet/d" -e "/^snippet/! s/^/\t/" -e 's/\\//g' > snipmate/tf.snippets
