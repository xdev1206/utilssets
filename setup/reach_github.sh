#!/bin/bash

function reach_github()
{
  local url="https://github.com"
  local code=`curl -I -s ${url} -w %{http_code} | tail -n1`
  if [ "x${code}" == "x200" ]; then
    reach_ok=1
  else
    reach_ok=0
  fi
}

reach_github
