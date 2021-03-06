#!/bin/bash
# Update source for glslang, spirv-tools

set -e

if [[ $(uname) == "Linux" || $(uname) =~ "CYGWIN" ]]; then
    CURRENT_DIR="$(dirname "$(readlink -f ${BASH_SOURCE[0]})")"
    CORE_COUNT=$(nproc || echo 4)
elif [[ $(uname) == "Darwin" ]]; then
    CURRENT_DIR="$(dirname "$(python -c 'import os,sys;print(os.path.realpath(sys.argv[1]))' ${BASH_SOURCE[0]})")"
    CORE_COUNT=$(sysctl -n hw.ncpu || echo 4)
fi
echo CURRENT_DIR=$CURRENT_DIR
echo CORE_COUNT=$CORE_COUNT

REVISION_DIR="$CURRENT_DIR/external_revisions"

GLSLANG_GITURL=$(cat "${REVISION_DIR}/glslang_giturl")
GLSLANG_REVISION=$(cat "${REVISION_DIR}/glslang_revision")
SPIRV_TOOLS_GITURL=$(cat "${REVISION_DIR}/spirv-tools_giturl")
SPIRV_TOOLS_REVISION=$(cat "${REVISION_DIR}/spirv-tools_revision")
SPIRV_HEADERS_GITURL=$(cat "${REVISION_DIR}/spirv-headers_giturl")
SPIRV_HEADERS_REVISION=$(cat "${REVISION_DIR}/spirv-headers_revision")
JSONCPP_REVISION=$(cat "${REVISION_DIR}/jsoncpp_revision")

echo "GLSLANG_GITURL=${GLSLANG_GITURL}"
echo "GLSLANG_REVISION=${GLSLANG_REVISION}"
echo "SPIRV_TOOLS_GITURL=${SPIRV_TOOLS_GITURL}"
echo "SPIRV_TOOLS_REVISION=${SPIRV_TOOLS_REVISION}"
echo "SPIRV_HEADERS_GITURL=${SPIRV_HEADERS_GITURL}"
echo "SPIRV_HEADERS_REVISION=${SPIRV_HEADERS_REVISION}"
echo "JSONCPP_REVISION=${JSONCPP_REVISION}"

BUILDDIR=${CURRENT_DIR}
BASEDIR="$BUILDDIR/external"

function create_glslang () {
   rm -rf "${BASEDIR}"/glslang
   echo "Creating local glslang repository (${BASEDIR}/glslang)."
   mkdir -p "${BASEDIR}"/glslang
   cd "${BASEDIR}"/glslang
   git clone ${GLSLANG_GITURL} .
   git checkout ${GLSLANG_REVISION}
   ./update_glslang_sources.py
}

function update_glslang () {
   echo "Updating ${BASEDIR}/glslang"
   cd "${BASEDIR}"/glslang
   git fetch --all
   git checkout --force ${GLSLANG_REVISION}
   ./update_glslang_sources.py
}

function create_spirv-tools () {
   rm -rf "${BASEDIR}"/spirv-tools
   echo "Creating local spirv-tools repository (${BASEDIR}/spirv-tools)."
   mkdir -p "${BASEDIR}"/spirv-tools
   cd "${BASEDIR}"/spirv-tools
   git clone ${SPIRV_TOOLS_GITURL} .
   git checkout ${SPIRV_TOOLS_REVISION}
   mkdir -p "${BASEDIR}"/spirv-tools/external/spirv-headers
   cd "${BASEDIR}"/spirv-tools/external/spirv-headers
   git clone ${SPIRV_HEADERS_GITURL} .
   git checkout ${SPIRV_HEADERS_REVISION}
}

function update_spirv-tools () {
   echo "Updating ${BASEDIR}/spirv-tools"
   cd "${BASEDIR}"/spirv-tools
   git fetch --all
   git checkout ${SPIRV_TOOLS_REVISION}
   if [ ! -d "${BASEDIR}/spirv-tools/external/spirv-headers" -o ! -d "${BASEDIR}/spirv-tools/external/spirv-headers/.git" ]; then
      mkdir -p "${BASEDIR}"/spirv-tools/external/spirv-headers
      cd "${BASEDIR}"/spirv-tools/external/spirv-headers
      git clone ${SPIRV_HEADERS_GITURL} .
   else
      cd "${BASEDIR}"/spirv-tools/external/spirv-headers
      git fetch --all
   fi
   git checkout ${SPIRV_HEADERS_REVISION}
}

function build_glslang () {
   echo "Building ${BASEDIR}/glslang"
   cd "${BASEDIR}"/glslang
   mkdir -p build
   cd build
   cmake -D CMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=install ..
   make -j $CORE_COUNT
   make install
}

function build_spirv-tools () {
   echo "Building ${BASEDIR}/spirv-tools"
   cd "${BASEDIR}"/spirv-tools
   mkdir -p build
   cd build
   cmake -D CMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=install ..
   make -j $CORE_COUNT
}

function create_jsoncpp () {
   rm -rf ${BASEDIR}/jsoncpp
   echo "Creating local jsoncpp repository (${BASEDIR}/jsoncpp)."
   mkdir -p ${BASEDIR}/jsoncpp
   cd ${BASEDIR}/jsoncpp
   git clone https://github.com/open-source-parsers/jsoncpp.git .
   git checkout ${JSONCPP_REVISION}
}

function update_jsoncpp () {
   echo "Updating ${BASEDIR}/jsoncpp"
   cd ${BASEDIR}/jsoncpp
   git fetch --all
   git checkout ${JSONCPP_REVISION}
}

function build_jsoncpp () {
   echo "Building ${BASEDIR}/jsoncpp"
   cd ${BASEDIR}/jsoncpp
   python amalgamate.py
}

INCLUDE_GLSLANG=false
INCLUDE_SPIRV_TOOLS=false
INCLUDE_JSONCPP=false
NO_SYNC=false
NO_BUILD=false
USE_IMPLICIT_COMPONENT_LIST=true

# Parse options
while [[ $# > 0 ]]
do
  option="$1"

  case $option in
      # options to specify build of glslang components
      -g|--glslang)
      INCLUDE_GLSLANG=true
      USE_IMPLICIT_COMPONENT_LIST=false
      echo "Building glslang ($option)"
      ;;
      # options to specify build of spirv-tools components
      -s|--spirv-tools)
      INCLUDE_SPIRV_TOOLS=true
      USE_IMPLICIT_COMPONENT_LIST=false
      echo "Building spirv-tools ($option)"
      ;;
      # options to specify build of jsoncpp components
      -j|--jsoncpp)
      INCLUDE_JSONCPP=true
      USE_IMPLICIT_COMPONENT_LIST=false
      echo "Building jsoncpp ($option)"
      ;;
      # option to specify skipping sync from git
      --no-sync)
      NO_SYNC=true
      echo "Skipping sync ($option)"
      ;;
      # option to specify skipping build
      --no-build)
      NO_BUILD=true
      echo "Skipping build ($option)"
      ;;
      *)
      echo "Unrecognized option: $option"
      echo "Usage: update_external_sources.sh [options]"
      echo "  Available options:"
      echo "    -g | --glslang      # enable glslang component"
      echo "    -s | --spirv-tools  # enable spirv-tools component"
      echo "    -j | --jsoncpp      # enable jsoncpp component"
      echo "    --no-sync           # skip sync from git"
      echo "    --no-build          # skip build"
      echo "  If any component enables are provided, only those components are enabled."
      echo "  If no component enables are provided, all components are enabled."
      echo "  Sync uses git to pull a specific revision."
      echo "  Build configures CMake, builds Release."
      exit 1
      ;;
  esac
  shift
done

if [ ${USE_IMPLICIT_COMPONENT_LIST} == "true" ]; then
  echo "Building glslang, spirv-tools, and jsoncpp"
  INCLUDE_GLSLANG=true
  INCLUDE_SPIRV_TOOLS=true
  INCLUDE_JSONCPP=true
fi

if [ ${INCLUDE_GLSLANG} == "true" ]; then
  if [ ${NO_SYNC} == "false" ]; then
    if [ ! -d "${BASEDIR}/glslang" -o ! -d "${BASEDIR}/glslang/.git" -o -d "${BASEDIR}/glslang/.svn" ]; then
       create_glslang
    fi
    update_glslang
  fi
  if [ ${NO_BUILD} == "false" ]; then
    build_glslang
  fi
fi


if [ ${INCLUDE_SPIRV_TOOLS} == "true" ]; then
  if [ ${NO_SYNC} == "false" ]; then
    if [ ! -d "${BASEDIR}/spirv-tools" -o ! -d "${BASEDIR}/spirv-tools/.git" ]; then
       create_spirv-tools
    fi
    update_spirv-tools
  fi
  if [ ${NO_BUILD} == "false" ]; then
    build_spirv-tools
  fi
fi

if [ ${INCLUDE_JSONCPP} == "true" ]; then
    if [ ! -d "${BASEDIR}/jsoncpp" -o ! -d "${BASEDIR}/jsoncpp/.git" ]; then
       create_jsoncpp
    fi
    update_jsoncpp
    build_jsoncpp
fi
