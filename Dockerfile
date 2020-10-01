FROM ubuntu:18.04
RUN apt-get update \
	&& DEBIAN_FRONTEND=noninteractive \
	&& apt-get install -y \
		python \
		build-essential \
		g++ \
		perl \
		libreadline6-dev \
		libcurl4-gnutls-dev \
		curl \
		unzip \
	&& rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN curl -LO https://github.com/OpenKore/openkore/archive/master.zip \
	&& mv master.zip root/ \
	&& cd root/ \
	&& unzip master.zip \
	&& rm -f master.zip

WORKDIR /root/openkore-master/

VOLUME ["/root/openkore-master/control/"]

CMD ["perl", "openkore.pl"]

