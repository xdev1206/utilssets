#!/bin/bash

function reach_github()
{
  local curl_path=$(command -v "curl")
  if [ "x${curl_path}" == "x" ]; then
    $SUDO ${INSTALL_CMD} curl
    echo "$(basename "$0"): install curl"
  fi

  local url="https://github.com"
  local code=`curl -I -s ${url} -w %{http_code} | tail -n1`
  if [ "x${code}" == "x200" ]; then
    reach_network=1
  else
    reach_network=0
  fi
  echo "connecting to github.com, status: $reach_network, http_code: $code"
  echo "reach_network: ${reach_network}"
}

reach_github
