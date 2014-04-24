name             'vcy-elasticsearch'
maintainer       'vacay'
maintainer_email 'admin@vacay.io'
license          'MIT'
description      'Installs/Configures vcy-elasticsearch'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          '0.1.0'

depends 'elasticsearch'

provides 'vcy-elasticsearch'
