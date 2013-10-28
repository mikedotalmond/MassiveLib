:: clear bin directory
rmdir bin /s /q
mkdir bin

:: build tool
haxe build.hxml

:: set mlib to dev
haxelib dev mlib ./src

:: run tests
cd test/haxe
haxelib run munit test -coverage

cd ../sys
haxelib run munit test -coverage

cd ../../

:: package up and install over current version
neko mlib.n install

haxelib run mlib help

:: submit to haxelib
:: #neko mlib.n submit