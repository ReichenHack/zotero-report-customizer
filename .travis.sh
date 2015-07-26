#!/bin/bash

set -e
set -u

rake
XPI=`ls *.xpi`
RELEASE="$TRAVIS_COMMIT release: $XPI"
CHECKIN=`git log -n 1 --pretty=oneline`
echo "checkin: $CHECKIN"
echo "release: $RELEASE"
if [ "$CHECKIN" = "$RELEASE" ] ; then
   sed -i.bak -e 's/git@github.com:/https:\/\/github.com\//' .gitmodules
   if [ -f .git/modules/www/config ] ; then # how can this be absent?!
     sed -i.bak -e 's/git@github.com:/https:\/\/github.com\//' .git/modules/www/config
   fi
   echo "https://${GITHUB_TOKEN}:@github.com" > /tmp/credentials
   git config --global credential.helper "store --file=/tmp/credentials"

   git submodule update --init
   (cd www && git checkout master && git pull)
   git config --global user.name "retorquere"
   git config --global user.email "retorquere@ZotPlus.github.com"
   git config --global push.default matching
   bundle exec rake deploy
   git checkout . # prevent travis release rebuilds?
else
  echo 'not a tagged release'
fi
