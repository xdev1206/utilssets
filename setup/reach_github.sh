#!/bin/bash

function reach_github()
{
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
