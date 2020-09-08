FROM theiaide/theia-full:next

USER root

RUN yes | unminimize \
 && apt-get install -y -q man-db manpages manpages-posix zsh lsof htop vim dos2unix gawk jq netcat rsync sshpass strace squashfs-tools tmux xmlstarlet \
 && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* \
 && chsh -s /usr/bin/zsh theia

USER theia

ENV TZ=Europe/Paris \
    LANG=fr_FR.UTF-8 \
    SHELL=/usr/bin/zsh

RUN curl -fsSL "https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh" | sh - \
 && git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k

COPY settings.json /home/theia/.theia/settings.json

COPY dot-zshrc /home/theia/.zshrc
COPY dot-p10k.zsh /home/theia/.p10k.zsh
