## build our app in python
FROM centos:centos7

ENV USERMAP_UID 1000
ENV HOME /home/runner
ENV APP_HOME /home/runner/app

RUN mkdir -p $HOME \
    && mkdir -p $APP_HOME

# Add non-root runner user
RUN groupadd -r runner && \
    useradd --no-log-init -u $USERMAP_UID -r -g runner runner && \
    groupadd docker && \
    usermod -aG docker runner

WORKDIR $APP_HOME

RUN yum update --quiet -y \
    && yum install --quiet -y \
    git \
    wget \
    make \
    gcc \
    jq \
    openssl-devel \
    zlib-devel \
    pcre-devel \
    bzip2-devel \
    libffi-devel \
    epel-release \
    sqlite-devel \
    && yum clean all --quiet -y

COPY --from=hashicorp/terraform:0.15.4 /bin/terraform /usr/local/bin

# Install Python3.7.2 and pip modules
RUN cd /usr/bin && \
    wget --quiet https://www.python.org/ftp/python/3.7.2/Python-3.7.2.tgz && \
    tar xzf Python-3.7.2.tgz && \
    cd Python-3.7.2 && \
    ./configure --enable-optimizations && \
    make altinstall && \
    alternatives --install /usr/bin/python python /usr/local/bin/python3.7 1

COPY . .

RUN python -m pip install --no-cache-dir --quiet -r requirements.txt

# Fix yum installer with Python3.7 running as a global default
RUN sed -i '/#!\/usr\/bin\/python/c\#!\/usr\/bin\/python2.7' /usr/bin/yum && \
    sed -i '/#! \/usr\/bin\/python/c\#! \/usr\/bin\/python2.7' /usr/libexec/urlgrabber-ext-down

RUN python -m pip install .

RUN chown -R runner:runner $HOME \
    && chmod -R 700 $HOME

USER ${USERMAP_UID}

RUN pylint **/*.py \
    && coverage run -m unittest tests/*_test.py \
    && coverage report

CMD python -m unittest tests/*_test.py
