FROM node:23

ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
ENV PATH=$PATH:/root/.cargo/bin
ENV DOCKER_CONTAINER=true
ENV DISPLAY=:99

RUN --mount=type=cache,id=apt-cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,id=apt-lists,target=/var/lib/apt/lists,sharing=locked \
    apt upgrade -y && apt update -y && apt-get install -y apt-utils openssl curl lsof dtach libssl-dev build-essential gnome-keyring libsecret-1-0 libsecret-1-dev libsecret-tools dbus-x11 wget 

# install gh cli
RUN mkdir -p -m 755 /etc/apt/keyrings \
	&& out=$(mktemp) && wget -nv -O$out https://cli.github.com/packages/githubcli-archive-keyring.gpg \
	&& cat $out | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
	&& chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
	&& mkdir -p -m 755 /etc/apt/sources.list.d \
	&& echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
	&& apt update -y \
	&& apt install gh -y

RUN curl https://sh.rustup.rs -sSf | bash -s -- -y
RUN curl -L --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/cargo-bins/cargo-binstall/main/install-from-binstall-release.sh | bash

RUN cargo binstall --strategies crate-meta-data jj-cli
RUN curl -fsSL https://get.docker.com | sh

RUN wget -qO- https://get.pnpm.io/install.sh | ENV="$HOME/.bashrc" SHELL="$(which bash)" bash -

RUN mkdir -p /pnpm
RUN pnpm config set global-bin-dir /pnpm
RUN pnpm config set global-dir /pnpm

RUN --mount=type=cache,id=pnpm2,target=/pnpm/store pnpm install -g @anthropic-ai/claude-code

RUN mkdir /workspace
RUN mkdir -p ~/.local/share/keyrings

WORKDIR /workspace

RUN docker context create workerd --docker "host=unix:///var/run/workerd.sock"

RUN mkdir -p /root/.local/share/code-server/User
RUN ln -s /workspace/.vscode/settings.json /root/.local/share/code-server/User/settings.json
RUN curl -fsSL https://code-server.dev/install.sh | sh
#  --extensions-dir=/workspace/code-server/extensions --user-data-dir=/workspace/code-server/data
RUN code-server  --install-extension github.github-vscode-theme
RUN code-server --install-extension svelte.svelte-vscode
RUN code-server --install-extension bradlc.vscode-tailwindcss
RUN code-server --install-extension kokakiwi.vscode-capnproto
RUN code-server --install-extension file-icons.file-icons
RUN code-server --install-extension anthropic.claude-code
# RUN code-server --install-extension rooveterinaryinc.roo-cline (crashes)
# RUN code-server --install-extension saoudrizwan.claude-dev
RUN code-server --install-extension visualjj.visualjj
RUN code-server --install-extension github.vscode-pull-request-github
RUN code-server --install-extension github.vscode-github-actions
RUN code-server --install-extension ms-vscode.vscode-github-issue-notebooks
RUN code-server --install-extension ms-azuretools.vscode-containers
RUN code-server --install-extension ms-playwright.playwright
RUN code-server --install-extension ms-toolsai.jupyter
RUN code-server --install-extension gruntfuggly.todo-tree
RUN code-server --install-extension yoavbls.pretty-ts-errors
RUN code-server --install-extension esbenp.prettier-vscode
RUN code-server --install-extension pomdtr.excalidraw-editor
RUN code-server --install-extension dbaeumer.vscode-eslint
RUN code-server --install-extension arktypeio.arkdark
RUN code-server --install-extension google.iwa-studio
# caddy

# working tab code completions:
RUN code-server --install-extension sourcegraph.amp
RUN code-server --install-extension kilocode.kilo-code

# lanes
# RUN code-server --install-extension l-igh-t.vscode-theme-seti-folder
# RUN code-server --install-extension thang-nm.flow-icons
# RUN code-server --install-extension adrianwilczynski.toggle-hidden
# remove: dart, groovy, etc.

COPY ./start.sh /root/start.sh
RUN chmod +x /root/start.sh
COPY ./package.json /tmp/node_workspace/package.json

#  --mount=type=cache,id=pnpm2,target=/pnpm/store
RUN cd /tmp/node_workspace && pnpm install

# replace <meta name="apple-mobile-web-app-capable" content="yes" /> in /usr/lib/code-server/lib/vscode/out/vs/code/browser/workbench/workbench.html with <meta name="apple-mobile-web-app-capable" content="yes" /> <style>body { background-color: #000; }</style>
RUN sed -i 's/<meta name="apple-mobile-web-app-capable" content="yes" \/>/<meta name="apple-mobile-web-app-capable" content="yes" \/> <style>body { background-color: #000; }<\/style>/' /usr/lib/code-server/lib/vscode/out/vs/code/browser/workbench/workbench.html

# COPY . /workspace/

RUN git config --global init.defaultBranch main
RUN jj config set --user ui.default-command log
RUN jj config set --user ui.pager cat
RUN jj config set --user git.auto-local-bookmark true

RUN --mount=type=bind,source=./,target=/tmp/workdir jj git clone --colocate --depth 10 /tmp/workdir /workspace
RUN jj new master

# auto-local-bookmark = true
# abandon-unreachable-commits = false

RUN jj git remote set-url origin https://$GH_USERNAME:$GH_TOKEN@github.com/Agent54/xe-orchestrator.git

RUN mv /tmp/node_workspace/node_modules /workspace/

RUN jj
RUN ls -la /workspace/

RUN echo "source /workspace/.bashrc" >> /root/.bashrc

# add .xe-state to global gitignore
RUN echo ".xe-state" >> /root/.gitignore

# ENTRYPOINT bash
# CMD /root/start.sh

CMD ["/root/start.sh"]
