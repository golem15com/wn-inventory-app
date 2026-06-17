# syntax=docker/dockerfile:1
# Inventory edge proxy — a tiny self-contained nginx image that owns the public
# port and unifies the origin (D-13). It bakes BOTH the vhost and the shared
# header include so the `include /etc/nginx/proxy_headers.conf` resolves and
# nginx starts cleanly (no host bind-mounts).
FROM nginx:alpine
COPY docker/proxy.nginx.conf /etc/nginx/conf.d/default.conf
COPY docker/proxy_headers.conf /etc/nginx/proxy_headers.conf
EXPOSE 80
