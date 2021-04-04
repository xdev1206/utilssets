#!/bin/bash

SCRIPT_PATH=$(cd `dirname $BASH_SOURCE[0]` && /bin/pwd)
source ${SCRIPT_PATH}/os_type.sh
source ${SCRIPT_PATH}/path.sh

JAR_PATH=${ENV_ROOT}/tool/jar

# setup jar environment
jar_env()
{
  if [ -d $JAR_PATH ]; then
    $SUDO rm -rf $JAR_PATH
  fi

  mkdir -p $JAR_PATH

  # install graphviz
  $SUDO ${INSTALL_CMD} graphviz

  if [ ! -d $HOME/.config ]; then
    mkdir -p $HOME/.config
    chmod 755 $HOME/.config
  fi

  # get plantuml.jar must be last step in func_toolenv_setup
  wget https://sourceforge.net/projects/plantuml/files/plantuml.jar/download -O $JAR_PATH/plantuml.jar
  # create plantuml shell script
  echo -e '#!/bin/bash\n' > $ENV_BIN/plantuml
  echo "java -jar $JAR_PATH/jar/plantuml.jar -tpng \$@" >> $ENV_BIN/plantuml
  chmod 755 $ENV_BIN/plantuml
}

jar_env
