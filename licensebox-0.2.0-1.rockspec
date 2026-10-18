package='licensebox'
version='0.2.0-1'
source={url='git+https://github.com/licensebox/lua.git',tag='v0.2.0'}
description={summary='Native Licensebox application SDK',homepage='https://meshing.engineer',license='MIT',maintainer='Vijai Kumar'}
dependencies={'lua >= 5.1, < 5.3','lua-cjson >= 2.1'}
build={type='builtin',modules={licensebox='licensebox/init.lua'}}
