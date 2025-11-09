export PATH="$HOME/.jenv/bin:$PATH"
eval "$(jenv init -)"

jenv add /opt/homebrew/opt/openjdk@17
jenv add /opt/homebrew/opt/openjdk@21

jenv versions
jenv global 21
