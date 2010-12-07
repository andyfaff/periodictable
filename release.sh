#!/bin/bash

# Usage: ./release.sh
#
# Build an official elements package release
#
# Releasing this package requires some setup in your local environment
#    nosetests and coverage package
#    sphinx and latex
#    mathjax with \AA extension
#    hudson server set up to build/test on windows/mac
#    reflectometry.org server key for updating docs
#    ~/.pypirc should be defined
#
# The patched MathJax (see below) needs to be symlinked into your
# doc/sphinx directory.

# The following is a minimal patch to MathJax to use the Angstrom symbol in TeX
# == MathJax/unpacked/jax/input/TeX/jax.js ==
#           // Ord symbols
#           S:            '00A7',
# +         AA:           '212B',
#           aleph:        ['2135',{mathvariant: MML.VARIANT.NORMAL}],
#           hbar:         '210F',

# Adapt the following to your own username/password for pypi, and get yourself
# added to the periodictable package.
# == ~/.pyirc ==
# [distutils]
# index-servers =
#     pypi
#   
# [pypi]
# username:...
# password:...

function ready() {
   echo -n "$* [y/n] "
   read ans && test "$ans" != "y" && exit
}

echo === Version control status ===
git pull
git status
ready Is the repository up to date?

echo === Tests ===
set -x
python2.6 test.py -q --with-coverage
python2.5 test.py -q
set +x
if true; then
    echo
    # Ask hudson build server if package is working on all platforms
    hudson_server="localhost:8080"
    elements_job="elements"
    url="http://$hudson_server/job/$elements_job/lastBuild"
    jsonurl="$url/api/json?depth=0"
    if curl --silent $jsonurl | grep -q SUCCESS ; then
        echo latest hudson build was successful
    else
        echo **** latest hudson build failed ... see $url
        firefox $url &
    fi
fi
ready Are the tests okay?

echo === Documentation ===
(cd doc/sphinx && make clean html pdf)
firefox doc/sphinx/_build/html/index.html >/dev/null 2>&1 & 
evince doc/sphinx/_build/latex/PeriodicTable.pdf >/dev/null 2>&1 &
ready Does the documentation build cleanly, and pdf/html display correctly?

echo === Release notes ===
rst2html README.rst > /tmp/README.html
firefox /tmp/README.html >/dev/null 2>&1 &
git log --oneline
ready Are the release notes up to date?

version=$(grep __version__ periodictable/__init__.py | sed -e's/^.*= *//')
echo === Version is $version ===
ready Is the version number correct?

ready Push docs to the web?
ssh reflectometry.org rm -r web/danse/docs/elements
find doc/sphinx/_build/html | xargs chmod ug+rw
find doc/sphinx/_build/html -type d | xargs chmod g+x
rm -r doc/sphinx/_build/html/_static/MathJax
(cd doc/sphinx/_build && scp -r html reflectometry.org:web/danse/docs/elements)
ssh reflectometry.org ln -s /var/www/reflectometry/MathJax web/danse/docs/elements/_static

ready Documentation upload successful?

ready Push package to pypi?
python setup.py sdist upload
ready Package upload successful?

echo == All done! ==