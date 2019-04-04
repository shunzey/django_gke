FROM centos:7

RUN yum update -y && \
    yum install -y git && \
    yum install -y https://centos7.iuscommunity.org/ius-release.rpm && \
    yum install -y python36u python36u-libs python36u-devel python36u-pip

WORKDIR /django_gs

RUN python3.6 -m pip install --upgrade pip
RUN python3.6 -m pip install mypackage
ADD django_gs/requirements /django_gs/requirements
RUN python3.6 -m pip install -r requirements

ADD django_gs /django_gs
#ADD id_rsa /root/.ssh/id_rsa
#RUN chmod 600 /root/.ssh/id_rsa
#RUN ssh-keyscan bitbucket.org >> /root/.ssh/known_hosts
#RUN git clone git@bitbucket.org:shunzey/django_gs.git
#RUN rm -rf /root/.ssh/id_rsa
