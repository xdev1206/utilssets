#!/bin/bash

addgroup --gid gid group_name
adduser --uid uid --gid gid user_name
usermod -a -G sudo user_name # add user to sudo group
