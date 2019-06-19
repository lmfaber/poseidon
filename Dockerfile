FROM ubuntu:18.04

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
ENV POSEIDON_VERSION 0.1
RUN wget --quiet https://github.com/lmfaber/poseidon/archive/$POSEIDON_VERSION.zip -O poseidon.zip
RUN unzip -qq poseidon.zip
RUN rm poseidon.zip
ENV PATH="PATH=${PATH}:/home/poseidon-$POSEIDON_VERSION/ruby:/home/poseidon-$POSEIDON_VERSION/tools/muscle:/home/poseidon-$POSEIDON_VERSION/tools/nw_utilities:/home/poseidon-$POSEIDON_VERSION/tools/paml4:/home/poseidon-$POSEIDON_VERSION/tools/raxml/8.0.25:/home/poseidon-$POSEIDON_VERSION/tools/translatorx"

# Ignore "hwloc has encountered what looks like an error from the operating system." errors. See: https://www.open-mpi.org/projects/hwloc/doc/v1.11.2/a00030.php
ENV HWLOC_HIDE_ERRORS=1

