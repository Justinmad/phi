# based on openresty:trusty
FROM    openresty/openresty:trusty
COPY    ./ /home/phi/
ENV     PATH=$PATH:/usr/local/openresty/nginx/sbin
RUN     ls -la /home/phi
EXPOSE  80 9090 12345
CMD     /home/phi/bin/phi restart -d