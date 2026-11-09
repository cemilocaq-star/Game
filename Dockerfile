FROM barichello/godot-ci:4.4.1

WORKDIR /game
COPY . .
EXPOSE 2456/udp
EXPOSE 8080/tcp

CMD ["godot", "--headless", "--path", "/game", "--", "--server"]
