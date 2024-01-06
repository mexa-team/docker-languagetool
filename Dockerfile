ARG LANGUAGETOOL_VERSION=6.3-branch

FROM debian:bookworm as build

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update -y \
    && apt-get install -y \
    locales \
    bash \
    libgomp1 \
    openjdk-17-jdk-headless \
    git \
    maven \
    unzip \
    xmlstarlet \
    build-essential \
    cmake \
    mercurial \
    texlive \
    wget \
    zip \
    && apt-get clean

RUN sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    dpkg-reconfigure --frontend=noninteractive locales && \
    update-locale LANG=en_US.UTF-8
ENV LANG en_US.UTF-8

ARG LANGUAGETOOL_VERSION
RUN git clone https://github.com/mexa-team/languagetool --depth 1
WORKDIR /languagetool
RUN ["mvn", "--projects", "languagetool-standalone", "--also-make", "package", "-DskipTests", "--quiet"]
RUN LANGUAGETOOL_DIST_VERSION=$(xmlstarlet sel -N "x=http://maven.apache.org/POM/4.0.0" -t -v "//x:project/x:properties/x:revision" pom.xml) && unzip /languagetool/languagetool-standalone/target/LanguageTool-${LANGUAGETOOL_DIST_VERSION}.zip -d /dist
RUN LANGUAGETOOL_DIST_FOLDER=$(find /dist/ -name 'LanguageTool-*') && mv $LANGUAGETOOL_DIST_FOLDER /dist/LanguageTool


WORKDIR /languagetool

# Note: When changing the base image, verify that the hunspell.sh workaround is
# downloading the matching version of `libhunspell`. The URL may need to change.
FROM alpine:3.19.0

RUN apk add --no-cache \
    bash \
    curl \
    libc6-compat \
    libstdc++ \
    openjdk11-jre-headless

RUN addgroup -S languagetool && adduser -S languagetool -G languagetool

COPY --chown=languagetool --from=build /dist .

WORKDIR /LanguageTool

RUN mkdir /nonexistent && touch /nonexistent/.languagetool.cfg

COPY --chown=languagetool start.sh start.sh
RUN dos2unix start.sh
COPY --chown=languagetool config.properties config.properties

USER languagetool

HEALTHCHECK --timeout=10s --start-period=5s CMD curl --fail --data "language=en-US&text=a simple test" http://localhost:8010/v2/check || exit 1

CMD [ "bash", "/LanguageTool/start.sh" ]

EXPOSE 8010
