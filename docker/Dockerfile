FROM ubuntu:latest

ARG USER_ID=1000
ARG GROUP_ID=1000
ARG USER_NAME=user

RUN apt update && apt upgrade -y
RUN apt install -y jq curl screen netcat-openbsd gnupg

RUN groupadd -g ${GROUP_ID} ${USER_NAME} \
    && useradd -m -u ${USER_ID} -g ${GROUP_ID} -s /bin/bash ${USER_NAME}

# Install gum
RUN mkdir -p /etc/apt/keyrings
RUN curl -fsSL https://repo.charm.sh/apt/gpg.key | gpg --dearmor -o /etc/apt/keyrings/charm.gpg
RUN echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | tee /etc/apt/sources.list.d/charm.list
RUN apt update && apt install -y gum

COPY .. /home/${USER_NAME}/server-mgr
RUN chown -R ${USER_ID}:${GROUP_ID} /home/${USER_NAME}/server-mgr

USER ${USER_ID}:${GROUP_ID}

WORKDIR /home/${USER_NAME}

ENV PROXY_NAME="proxy"

CMD ["bash", "-c", "./server-mgr/serman.sh start \"$PROXY_NAME\"; exec bash"]

