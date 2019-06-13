FROM ubuntu:18.04
LABEL MAINTAINER="lmfaber"

# docker run --rm -it --mount type=bind,source=/mnt/prostlocal/lasse/hiwi/bat/oas_cds,target=/home/fasta,readonly --mount type=bind,source=/mnt/prostlocal/lasse/hiwi/bat/poseidon_results/,target=/home/output --mount type=bind,source=/mnt/prostlocal/lasse/hiwi/bat/poseidon/,target=/home/poseidon ubuntu:18.04 /bin/bash

RUN apt-get update && apt-get install -y \
	hyphy-mpi=2.2.7+dfsg-1 \
	inkscape \
	openmpi-bin=2.1.1-8 \
	openssh-client \ 
	ruby-full \
	ruby-dev \
	texlive-latex-base \
	wget
RUN gem install \
	bio \
	mail \
	encrypted_strings


# Install latex packages
WORKDIR /usr/share/texmf/tex/latex/
RUN wget --quiet http://mirrors.ctan.org/macros/latex/contrib/multirow.zip http://mirrors.ctan.org/macros/latex/contrib/booktabs.zip http://mirrors.ctan.org/macros/latex/required/tools.zip
RUN unzip -qq \*.zip
RUN rm multirow.zip booktabs.zip tools.zip

WORKDIR /usr/share/texmf/tex/latex/multirow
RUN latex multirow.ins
WORKDIR /usr/share/texmf/tex/latex/booktabs
RUN latex booktabs.ins
WORKDIR /usr/share/texmf/tex/latex/tools
RUN latex tools.ins

WORKDIR /usr/share/texmf
RUN mktexlsr
WORKDIR /home
RUN wget --quiet https://github.com/lmfaber/poseidon/archive/0.1.zip -O poseidon.zip
RUN unzip -qq poseidon.zip
RUN rm poseidon.zip
ENV PATH="PATH=${PATH}:/home/poseidon-0.1/ruby"



# Ignore "hwloc has encountered what looks like an error from the operating system." errors. See: https://www.open-mpi.org/projects/hwloc/doc/v1.11.2/a00030.php
ENV HWLOC_HIDE_ERRORS=1

